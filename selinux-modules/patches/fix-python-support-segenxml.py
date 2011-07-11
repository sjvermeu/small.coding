--- refpolicy.orig/policy/modules/../../support/segenxml.py	2009-07-14 14:24:48.000000000 +0200
+++ refpolicypolicy/modules/../../support/segenxml.py	2011-07-05 20:05:35.240000444 +0200
@@ -1,9 +1,9 @@
 #!/usr/bin/python
 
 #  Author(s): Donald Miner <dminer@tresys.com>
-#             Dave Sugar <dsugar@tresys.com>
-#             Brian Williams <bwilliams@tresys.com>
-#             Caleb Case <ccase@tresys.com>
+#	     Dave Sugar <dsugar@tresys.com>
+#	     Brian Williams <bwilliams@tresys.com>
+#	     Caleb Case <ccase@tresys.com>
 #
 # Copyright (C) 2005 - 2006 Tresys Technology, LLC
 #      This program is free software; you can redistribute it and/or modify
@@ -335,9 +335,9 @@
 	'''
 
 	sys.stderr.write("%s: " % sys.argv[0] )
-        sys.stderr.write("error: " + description + "\n")
-        sys.stderr.flush()
-        sys.exit(1)
+	sys.stderr.write("error: " + description + "\n")
+	sys.stderr.flush()
+	sys.exit(1)
 
 
 
