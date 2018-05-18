#!/bin/bash
set -x
set -e

CM_EXT_BRANCH=cm5-5.12.0

ZEPPELIN_URL=http://apache.mirror.anlx.net/zeppelin/zeppelin-0.7.3/zeppelin-0.7.3-bin-all.tgz
ZEPPELIN_MD5="6f84f5581f59838b632a75071a2157cc"
ZEPPELIN_VERSION=0.7.3

zeppelin_archive="$( basename $ZEPPELIN_URL )"
zeppelin_folder="$( basename $zeppelin_archive .tgz )"
zeppelin_parcel_folder="ZEPPELIN-${ZEPPELIN_VERSION}"
zeppelin_parcel_name="${zeppelin_parcel_folder}-el7.parcel"
zeppelin_built_folder="${zeppelin_parcel_folder}_build"

function build_cm_ext {

  #Checkout if dir does not exist
  if [ ! -d cm_ext ]; then
    git clone https://github.com/cloudera/cm_ext.git
  fi
  if [ ! -f cm_ext/validator/target/validator.jar ]; then
    cd cm_ext
    git checkout "$CM_EXT_BRANCH"
    mvn package
    cd ..
  fi
}

function get_zeppelin {
  if [ ! -f "$zeppelin_archive" ]; then
    wget $ZEPPELIN_URL
  fi
  zeppelin_md5="$( md5sum $zeppelin_archive | cut -d' ' -f1 )"
  if [ "$zeppelin_md5" != "$ZEPPELIN_MD5" ]; then
    echo ERROR: md5 of $zeppelin_archive is not correct
    exit 1
  fi
  if [ ! -d "$zeppelin_folder" ]; then
    tar -xzf $zeppelin_archive
  fi
}

function build_zeppelin_parcel {
  if [ -f "$zeppelin_built_folder/$zeppelin_parcel_name" ] && [ -f "$zeppelin_built_folder/manifest.json" ]; then
    return
  fi
  if [ ! -d $zeppelin_parcel_folder ]; then
    get_zeppelin
    mv $zeppelin_folder $zeppelin_parcel_folder
  fi
  cp -r zeppelin-parcel-src/meta $zeppelin_parcel_folder
  sed -i -e "s/%VERSION%/$ZEPPELIN_VERSION/" ./$zeppelin_parcel_folder/meta/parcel.json
  java -jar cm_ext/validator/target/validator.jar -d ./$zeppelin_parcel_folder
  mkdir -p $zeppelin_built_folder
  tar zcvhf ./$zeppelin_built_folder/$zeppelin_parcel_name $zeppelin_parcel_folder --owner=root --group=root
  java -jar cm_ext/validator/target/validator.jar -f ./$zeppelin_built_folder/$zeppelin_parcel_name
  python cm_ext/make_manifest/make_manifest.py ./$zeppelin_built_folder
}

function build_zeppelin_csd {
  JARNAME=ZEPPELIN-${ZEPPELIN_VERSION}.jar
  if [ -f "$JARNAME" ]; then
    return
  fi
  java -jar cm_ext/validator/target/validator.jar -s ./zeppelin-csd-src/descriptor/service.sdl

  jar -cvf ./$JARNAME -C ./zeppelin-csd-src .
}

case $1 in
clean)
  if [ -d cm_ext ]; then
    rm -rf cm_ext
  fi
  ;;
parcel)
  build_cm_ext
  build_zeppelin_parcel
  ;;
csd)
  build_zeppelin_csd
  ;;
*)
  echo "Usage: $0 [parcel|csd|clean]"
  ;;
esac
