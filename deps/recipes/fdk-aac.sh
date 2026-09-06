# fdk-aac — mstorsjo/fdk-aac (autotools)
GIT_URL="https://github.com/mstorsjo/fdk-aac"
BUILD() { autotools_driver "$SRC_ROOT/$NAME" CXXFLAGS="$CXXFLAGS -fno-rtti -fno-exceptions"; }
