ifeq ($(TARGET_OS), Android)
	PRJTYPE = DynLib
else
	PRJTYPE = Executable
endif
LIBS = EGL GLESv1_CM log android
