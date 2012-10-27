#!/bin/bash

# Itentify the script
bname="$(basename "$0")"
# Make a work dir
wdir="/tmp/$USER/$bname"
[[ ! -d "$wdir" ]] && mkdir -p "$wdir"

# Arg1: The bracket pair 'string'
pair="$1"
# pair='[]' # test
# pair='<>' # test
# pair='{}' # test
# pair='()' # test

# Arg2: The input file to test
  # Build a test source file
  ifile="$wdir/$bname.in"
  cp /dev/null "$ifile"
  while IFS= read -r line ;do
    echo "$line" >> "$ifile"
  done <<EOF
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
[   ]    [         [         [
<   >    <         
                   <         >         
                             <    >    >         >
----+----1----+----2----+----3----+----4----+----5----+----6
{   }    {         }         }         }         } 
(   )    (         (         (     )   )                    
ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ
EOF

ifile="$2"
echo "File = $ifile"
# Count how many: Left, Right, and Both
left=${pair:0:1}
rght=${pair:1:1}
echo "Pair = $left$rght"
# Make a stripped-down 'skeleton' of the source file - brackets only
skel="/tmp/$USER/$bname.skel" 
cp /dev/null "$skel"
# Make a String Of Brackets file ... (It is tricky manipulating bash strings with []..
sed 's/[^'${rght}${left}']//g' "$ifile" > "$skel"
< "$skel" tr  -d '\n'  > "$skel.str"
Left=($(<"$skel.str" tr -d "$left" |wc -m -l)); LeftCt=$((${Left[1]}-${Left[0]}))
Rght=($(<"$skel.str" tr -d "$rght" |wc -m -l)); RghtCt=$((${Rght[1]}-${Rght[0]}))
yBkts=($(sed -e "s/\(.\)/ \1 /g" "$skel.str"))
BothCt=$((LeftCt+RghtCt))
eleCtB=${#yBkts[@]}
echo

if (( eleCtB != BothCt )) ; then
  echo "ERROR:  array Item Count ($eleCtB)"
  echo "     should equal BothCt ($BothCt)"
  exit 1
else
  grpIx=0            # Keep track of Groups of nested pairs
  eleIxFir[$grpIx]=0 # Ix of First Bracket in a specific Group
  eleCtL=0           # Count of Left brackets in current Group 
  eleCtR=0           # Count of Right brackets in current Group
  errIx=-1           # Ix of an element in error.
  for (( eleIx=0; eleIx < eleCtB; eleIx++ )) ; do
    if [[ "${yBkts[eleIx]}" == "$left" ]] ; then
      # Left brackets are 'okay' until proven otherwise
      ((eleCtL++)) # increment Left bracket count
    else
      ((eleCtR++)) # increment Right bracket count
      # Right brackets are 'okay' until their count exceeds that of Left brackets
      if (( eleCtR > eleCtL )) ; then
        echo
        echo "ERROR:  MIS-matching Right \"$rght\" in Group $((grpIx+1)) (at Bracket $((eleIx+1)) overall)"
        errType=$rght    
        errIx=$eleIx    
        break
      elif (( eleCtL == eleCtR )) ; then
        echo "*INFO:  Group $((grpIx+1)) contains $eleCtL matching pairs"
        # Reset the element counts, and note the first element Ix for the next group
        eleCtL=0
        eleCtR=0
        ((grpIx++))
        eleIxFir[$grpIx]=$((eleIx+1))
      fi
    fi
  done
  #
  if (( eleCtL > eleCtR )) ; then
    # Left brackets are always potentially valid (until EOF)...
    # so, this 'error' is the last element in array
    echo
    echo "ERROR: *END-OF-FILE* encountered after Bracket $eleCtB."
    echo "        A Left \"$left\" is un-paired in Group $((grpIx+1))."
    errType=$left
    unpairedCt=$((eleCtL-eleCtR))
    errIx=$((${eleIxFir[grpIx]}+unpairedCt-1))
    echo "        Group $((grpIx+1)) has $unpairedCt un-paired Left \"$left\"."
    echo "        Group $((grpIx+1)) begins at Bracket $((eleIxFir[grpIx]+1))."
  fi

  # On error, get Line and Column numbers
  if (( errIx >= 0 )) ; then
    errLNum=0    # Source Line number (current).
    eleCtSoFar=0 # Count of bracket-elements in lines processed so far.
    errItemNum=$((errIx+1)) # error Ix + 1 (ie. "1 based")
    # Read the skeketon file to find the error line-number
    while IFS= read -r skline ; do
      ((errLNum++))
      brackets="${skline//[^"${rght}${left}"]/}" # remove whitespace
      ((eleCtSoFar+=${#brackets}))
      if (( eleCtSoFar >= errItemNum )) ; then
        # We now have the error line-number
        # ..now get the relevant Source Line 
        excerpt=$(< "$ifile" tail -n +$errLNum |head -n 1)
        # Homogenize the brackets (to be all "Left"), for easy counting
        mogX="${excerpt//$rght/$left}"; mogXCt=${#mogX} # How many 'Both' brackets on the error line? 
        if [[ "$errType" == "$left" ]] ; then
          # R-Trunc from the error element [inclusive]
          ((eleTruncCt=eleCtSoFar-errItemNum+1))
          for (( ele=0; ele<eleTruncCt; ele++ )) ; do
            mogX="${mogX%"$left"*}"   # R-Trunc (Lazy)
          done
          errCNum=$((${#mogX}+1))
        else
          # errType=$rght
          mogX="${mogX%"$left"*}"   # R-Trunc (Lazy)
          errCNum=$((${#mogX}+1))
        fi
        echo "  see:  Line, Column ($errLNum, $errCNum)"
        echo "        ----+----1----+----2----+----3----+----4----+----5----+----6----+----7"  
        printf "%06d  $excerpt\n\n" $errLNum
        break
      fi
    done < "$skel"
  else
    echo "*INFO:  OK. All brackets are paired."
  fi
fi
exit
