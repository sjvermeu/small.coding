#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <stdarg.h>

#define DEBUG  7
#define INFO   6
#define NOTICE 5
#define WARN   4
#define ERR    3
#define CRIT   2
#define ALERT  1
#define EMERG  0

#ifndef LOGLEVEL
#define LOGLEVEL 4
#endif

#ifdef SELINUX
#include <selinux/selinux.h>
#include <selinux/flask.h>
#include <selinux/av_permissions.h>
#include <selinux/get_context_list.h>
#endif

/* out - Simple output */
void out(int level, char * msg, ...) {
  if (level <= LOGLEVEL) {
    va_list ap;
    printf("%d - ", level);

    va_start(ap, msg);
    vprintf(msg, ap);
    va_end(ap);
  };
};

/* selinux_prepare_fork - Initialize context switching
 *
 * Returns
 *  - 0 if everything is OK, 
 *  - +1 if the code should continue, even if SELinux wouldn't allow
 *       (for instance due to permissive mode)
 *  - -1 if the code should not continue
 */
int selinux_prepare_fork(char * name) {
#ifndef SELINUX
  return 0;
#else
  security_context_t newcon = 0;
  security_context_t curcon = 0;
  struct av_decision avd;
  int rc;
  int permissive = 0;
  int dom_permissive = 0;

  char * sename = 0;
  char * selevel = 0;

  /*
   * See if SELinux is enabled.
   * If not, then we can immediately tell the code
   * that everything is OK.
   */
  rc = is_selinux_enabled();
  if (rc == 0) {
    out(DEBUG, "SELinux is not enabled.\n");
    return 0;
  } else if (rc == -1) {
    out(WARN, "Could not check SELinux state (is_selinux_enabled() failed)\n");
    return 1;
  };
  out(DEBUG, "SELinux is enabled.\n");

  /*
   * See if SELinux is in enforcing mode
   * or permissive mode
   */
  rc = security_getenforce();
  if (rc == 0) {
    permissive = 1;
  } else if (rc == 1) {
    permissive = 0;
  } else {
    out(WARN, "Could not check SELinux mode (security_getenforce() failed)\n");
  }
  out(DEBUG, "SELinux mode is %s\n", permissive ? "permissive" : "enforcing");

  /*
   * Get the current SELinux context of the process.
   * Always interesting to log this for end users
   * trying to debug a possible issue.
   */
  rc = getcon(&curcon);
  if (rc) {
    out(WARN, "Could not get current SELinux context (getcon() failed)\n");
    if (permissive)
      return +1;
    else
      return -1;
  };
  out(DEBUG, "Currently in SELinux context \"%s\"\n", (char *) curcon);
 
  /*
   * Get the SELinux user given the Linux user
   * name passed on to this function.
   */
  rc = getseuserbyname(name, &sename, &selevel);
  if (rc) {
    out(WARN, "Could not find SELinux user for Linux user \"%s\" (getseuserbyname() failed)\n", name);
    freecon(curcon);
    if (permissive)
      return +1;
    else
      return -1;
  };
  out(DEBUG, "SELinux user for Linux user \"%s\" is \"%s\"\n", name, sename);

  /*
   * Find out what the context is that this process should transition
   * to.
   */
  rc = get_default_context(sename, NULL, &newcon);
  if (rc) {
    out(WARN, "Could not deduce default context for SELinux user \"%s\" given our current context (\"%s\")\n", sename, (char *) curcon);
    freecon(curcon);
    if (permissive)
      return +1;
    else
      return -1;
  };
  out(DEBUG, "SELinux context to transition to is \"%s\"\n", (char *) newcon);

  /*
   * Now let's look if we are allowed to transition to the new context.
   * We currently only check the transition access for the process class. However,
   * transitioning is a bit more complex (execute rights on target context, 
   * entrypoint of that context for the new domain, no constraints like target
   * domain not being a valid one, MLS constraints, etc.).
   */
  rc = security_compute_av_flags(curcon, newcon, SECCLASS_PROCESS, PROCESS__TRANSITION, &avd);
  if (rc) {
    out(WARN, "Could not deduce rights for transitioning \"%s\" -> \"%s\" (security_compute_av_flags() failed)\n", (char *) curcon, (char *) newcon);
    freecon(curcon);
    freecon(newcon);
    if (permissive)
      return +1;
    else
      return -1;
  };
  /* Validate the response 
   *
   * We are interested in two things:
   * - Is the transition allowed, but also
   * - Is the permissive flag set
   *
   * If the permissive flag is set, then we
   * know the current domain is permissive
   * (even if the rest of the system is in
   * enforcing mode).
   */
  if (avd.flags & SELINUX_AVD_FLAGS_PERMISSIVE) {
    out(DEBUG, "The SELINUX_AVD_FLAGS_PERMISSIVE flag is set, so domain is permissive.\n");
    dom_permissive = 1;
  };
  if (!(avd.allowed & PROCESS__TRANSITION)) {
    // The transition is denied
    if (permissive) {
      out(DEBUG, "Transition is not allowed by SELinux, but permissive mode is enabled. Continuing.\n");
    };
    if (dom_permissive) {
      out(DEBUG, "Transition is not allowed by SELinux, but domain is in permissive mode. Continuing.\n");
    };
    if ((permissive == 0) && (dom_permissive == 0)) {
      out(WARN, "The domain transition is not allowed and we are not in permissive mode.\n");
      freecon(curcon);
      freecon(newcon);
      return -1;
    };
  };


  /*
   * Set the context for the fork (process execution).
   */
  rc = setexeccon(newcon);
  if (rc) {
    out(WARN, "Could not set execution context (setexeccon() failed)\n");
    freecon(curcon);
    freecon(newcon);
    if ((permissive) || (dom_permissive))
      return +1;
    else
      return -1;
  };

  freecon(newcon);
  freecon(curcon);

  return 0;
#endif
};

int main(int argc, char * argv[]) {
  int rc = 0;
  pid_t child;

  rc = selinux_prepare_fork(argv[1]);
  if (rc < 0) {
    out(WARN, "The necessary context change will fail.\n");
    // Continuing here would mean that the newly started process
    // runs in the wrong context (current context) which might
    // be either too privileged, or not privileged enough.
    return -1;
  } else if (rc > 0) {
    out(WARN, "The necessary context change will fail, but permissive mode is active.\n");
  };

  child = fork();
  if (child < 0) {
    out(WARN, "fork() failed\n", NULL);
  };

  if (child == 0) {
    int pidrc;
    pidrc = execl("/usr/bin/id", "id", "-Z", NULL);
    if (pidrc != 0) {
      out(WARN, "Command failed with return code %d\n", pidrc);
    };
    return(0);
  } else {
    int status;
    out(DEBUG, "Child is %d\n", child);
    wait(&status);
    out(DEBUG, "Child exited with %d\n", status);
  };
  return 0;
};
