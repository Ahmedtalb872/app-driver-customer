# cronet_http (Play Services Cronet distribution) references optional
# telemetry/http-flags/logger classes (org.chromium.base.metrics.*,
# org.chromium.net.httpflags.*, org.chromium.net.impl.CronetLogger*,
# CronetManifest) that are only present in the full/embedded Cronet AAR,
# not in the compile-time cronet-api stub used with Play Services. R8
# treats references to these missing classes as a fatal error by default;
# they are optional and never invoked at runtime on this distribution.
-dontwarn org.chromium.**
