#!/bin/bash

# You should tweak this section to adapt the paths to your need
export ANDROID_HOME=/usr/local/android-sdk
export NDK_ROOT=/usr/local/android-sdk/ndk/17.2.4988734
#echo ls /usr/local
#ls /usr/local
echo ls /usr/local/android-sdk
ls /usr/local/android-sdk
echo ls /usr/local/android-sdk/ndk/17.2.4988734
ls /usr/local/android-sdk/ndk/17.2.4988734
#echo ls /home/travis/build/leejoo71/openalpr-android/
#ls /home/travis/build/leejoo71/openalpr-android/
#echo ls /usr/local/android-sdk/ndk-bundle
#ls /usr/local/android-sdk/ndk-bundle
#echo head /usr/local/android-sdk/ndk-bundle/source.properties
#head /usr/local/android-sdk/ndk-bundle/source.properties
#ls /usr/local/android-sdk/ndk-bundle

export ANDROID_NDK_ROOT=$NDK_ROOT
#echo $HOME
#echo $ANDROID_HOME
#echo $NDK_ROOT
#echo $ANDROID_NDK_ROOT

export ANDROID_PLATFORM=27

# In my case, FindJNI.cmake does not find java, so i had to manually specify these
# You could try without it and remove the cmake variable specification at the bottom of this file
export JAVA_HOME=/usr/lib/jvm/java-8-oracle
export JAVA_AWT_LIBRARY=$JAVA_HOME/jre/lib/amd64
export JAVA_JVM_LIBRARY=$JAVA_HOME/jre/lib/amd64
export JAVA_INCLUDE_PATH=$JAVA_HOME/include
export JAVA_INCLUDE_PATH2=$JAVA_HOME/include/linux
export JAVA_AWT_INCLUDE_PATH=$JAVA_HOME/include

SCRIPTPATH=`pwd`
echo $SCRIPTPATH
####################################################################
# Prepare Tesseract and Leptonica, using rmtheis/tess-two repository
####################################################################

git clone --recursive https://github.com/rmtheis/tess-two.git tess2
#git clone --recursive https://github.com/alexcohn/tess-two.git tess2

cd tess2
# git checkout 434d54fb7a7b2d5bc412bc432a036e1cc9280a4f
echo "ndk.dir=$NDK_ROOT
sdk.dir=$ANDROID_HOME" > local.properties
head local.properties
./gradlew assemble
cd ..


####################################################################
# Download and extract OpenCV4Android
####################################################################

wget --no-check-certificate -O opencv-3.2.0-android-sdk.zip -- https://sourceforge.net/projects/opencvlibrary/files/opencv-android/3.2.0/opencv-3.2.0-android-sdk.zip/download
#https://sourceforge.net/projects/opencvlibrary/files/opencv-android/3.2.0/opencv-3.2.0-android-sdk.zip/download 
                                        
unzip opencv-3.2.0-android-sdk.zip
rm opencv-3.2.0-android-sdk.zip

####################################################################
# Download and configure openalpr from jav974/openalpr forked repo
####################################################################

git clone https://github.com/jav974/openalpr.git openalpr
mkdir openalpr/android-build

TESSERACT_SRC_DIR=$SCRIPTPATH/tess2/tess-two/jni/com_googlecode_tesseract_android/src

rm -rf openalpr/src/openalpr/ocr/tesseract
mkdir openalpr/src/openalpr/ocr/tesseract
shopt -s globstar
cd $TESSERACT_SRC_DIR

cp **/*.h $SCRIPTPATH/openalpr/src/openalpr/ocr/tesseract

cd $SCRIPTPATH
#"armeabi-v7a with NEON"
declare -a ANDROID_ABIS=("armeabi-v7a"
			 "arm64-v8a"
# 			 "x86"
# 			 "x86_64"
			)

cd openalpr/android-build

for i in "${ANDROID_ABIS[@]}"
do
    if [ "$i" == "armeabi-v7a with NEON" ]; then abi="armeabi-v7a"; else abi="$i"; fi
    TESSERACT_LIB_DIR=$SCRIPTPATH/tess2/tess-two/libs/$abi

    if [[ "$i" == armeabi* ]];
    then
	arch="arm"
	lib="lib"
    elif [[ "$i" == arm64-v8a ]];
    then
	arch="arm64"
	lib="lib"
    elif [[ "$i" == mips ]] || [[ "$i" == x86 ]];
    then
	arch="$i"
	lib="lib"
    elif [[ "$i" == mips64 ]] || [[ "$i" == x86_64 ]];
    then
	arch="$i"
	lib="lib64"
    fi
    
    echo "
######################################
Generating project for arch $i
######################################
"
    rm -rf "$i" && mkdir "$i"
    cd "$i"
    #-DANDROID_STL=gnustl_static \
    cmake \
	-DCMAKE_TOOLCHAIN_FILE=$NDK_ROOT/build/cmake/android.toolchain.cmake \
        -DANDROID_TOOLCHAIN=clang \
	-DANDROID_NDK=$NDK_ROOT \
	-DCMAKE_BUILD_TYPE=Release \
	-DANDROID_PLATFORM=$ANDROID_PLATFORM \
	-DANDROID_ABI="$i" \
	-DANDROID_CPP_FEATURES="rtti exceptions" \
	-DANDROID_STL=c++_static \
	-DANDROID_COMPILER_FLAGS=-lopencv_core -lopencv_imgcodecs -lopencv_highgui -lopencv_shape -lopencv_videoio -lopencv_calib3d -Wconstant-conversion \
	-DANDROID_LINKER_FLAGS=-lopencv_core
	-DANDROID_ARM_MODE=arm \
	-DANDROID_LD= -latomic \
	
	-DTesseract_INCLUDE_BASEAPI_DIR=$TESSERACT_SRC_DIR/api \
	-DTesseract_INCLUDE_CCSTRUCT_DIR=$TESSERACT_SRC_DIR/ccstruct \
	-DTesseract_INCLUDE_CCMAIN_DIR=$TESSERACT_SRC_DIR/ccmain \
	-DTesseract_INCLUDE_CCUTIL_DIR=$TESSERACT_SRC_DIR/ccutil \
	-DTesseract_LIB=$TESSERACT_LIB_DIR/libtess.so \
	-DLeptonica_LIB=$TESSERACT_LIB_DIR/liblept.so \
	-DOpenCV_DIR=$SCRIPTPATH/OpenCV-android-sdk/sdk/native/jni \
	-DJAVA_AWT_LIBRARY=$JAVA_AWT_LIBRARY \
	-DJAVA_JVM_LIBRARY=$JAVA_JVM_LIBRARY \
	-DJAVA_INCLUDE_PATH=$JAVA_INCLUDE_PATH \
	-DJAVA_INCLUDE_PATH2=$JAVA_INCLUDE_PATH2 \
	-DJAVA_AWT_INCLUDE_PATH=$JAVA_AWT_INCLUDE_PATH \
	-DPngt_LIB=$TESSERACT_LIB_DIR/libpngt.so \
	-DJpgt_LIB=$TESSERACT_LIB_DIR/libjpgt.so \
	-DJnigraphics_LIB=$NDK_ROOT/platforms/$ANDROID_PLATFORM/arch-$arch/usr/$lib/libjnigraphics.so \
	../../src/

    cmake --build . -- -j 8
    
    cd ..
done

echo "
All done !!!"
