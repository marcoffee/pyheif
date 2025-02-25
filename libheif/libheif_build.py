import os

from cffi import FFI

ffibuilder = FFI()

with open("libheif/libheif_api.h") as f:
    ffibuilder.cdef(f.read())

include_dirs = ["/usr/local/include", "/usr/include", "/opt/local/include"]
library_dirs = ["/usr/local/lib", "/usr/lib", "/lib", "/opt/local/lib"]

homebrew_prefix = os.getenv("HOMEBREW_PREFIX")
if homebrew_prefix:
    include_dirs.append(os.path.join(homebrew_prefix, "include"))
    library_dirs.append(os.path.join(homebrew_prefix, "lib"))

ffibuilder.set_source(
    "_libheif_cffi",
    """
    #include <libheif/heif.h>
    // 1.17.0+ stores properties in different files
    #if LIBHEIF_NUMERIC_VERSION >= 0x01110000
        #include <libheif/heif_properties.h>
    #endif
    """,
    include_dirs=include_dirs,
    library_dirs=library_dirs,
    libraries=["heif"],
)

if __name__ == "__main__":
    ffibuilder.compile(verbose=True)
