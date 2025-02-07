% disabe CRT to avoid user miss specific version of Microsoft Visual C++ Redistributable
mex -R2018a  COMPFLAGS="$COMPFLAGS /MT /NODEFAULTLIB" smcrc32.c
mex -R2018a  COMPFLAGS="$COMPFLAGS /MT /NODEFAULTLIB" smdecode.c