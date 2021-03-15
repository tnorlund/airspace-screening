#!/bin bash
#
# Sets up the requirements for the Python Lambda Layer

if ( ! test -f "../python.zip" ); then
  echo "Creating Python Lambda Layer"
  # Download all the required wheels
  while read p; do
    curl -O "$p" &> /dev/null;
  done < require.txt

  # Install wheel
  python -m pip install --upgrade pip &> /dev/null;
  python -m pip install wheel &> /dev/null;

  # Unpack all of the wheels
  for i in *.whl; do
    python -m wheel unpack "$i" &> /dev/null;
    rm $i;
  done

  # Make the required folder structure
  mkdir ../python;
  mkdir ../python/lib;
  mkdir ../python/lib/python3.8
  mkdir ../python/lib/python3.8/site-packages

  # Move the unpacked packages into the correct location
  for i in $(ls -d */); do  
    for j in $(ls $i); do
      mv -f "$i/$j" ../python/lib/python3.8/site-packages;
    done
    rm -rf $i
  done

  zip -r python.zip ./python &> /dev/null;
  # Clean up
  rm -rf python;
else
  echo "Lambda Layers already exist"
fi
