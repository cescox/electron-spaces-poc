{
  "targets": [
    {
      "target_name": "native_window_mac",
      "sources": [
        "src/native_window_mac.mm"
      ],
      "include_dirs": [
        "src",
        "<!@(node -p \"require('node-addon-api').include\")"
      ],
      "dependencies": [
        "<!(node -p \"require('node-addon-api').gyp\")"
      ],
      "cflags!": [ "-fno-exceptions" ],
      "cflags_cc!": [ "-fno-exceptions" ],
      "xcode_settings": {
        "GCC_ENABLE_CPP_EXCEPTIONS": "YES",
        "CLANG_CXX_LIBRARY": "libc++",
        "MACOSX_DEPLOYMENT_TARGET": "12.0",
        "OTHER_CPLUSPLUSFLAGS": [
          "-std=c++17",
          "-stdlib=libc++",
          "-ObjC++"
        ],
        "OTHER_LDFLAGS": [
          "-framework AppKit",
          "-framework Foundation"
        ]
      }
    }
  ]
}
