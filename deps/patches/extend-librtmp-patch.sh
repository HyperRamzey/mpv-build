#!/bin/bash
# extend librtmp patch: handshake.h HMAC_CTX (stack value) -> pointer API
set -e
cd /g/deps-build/src/librtmp

python - <<'PYEOF'
p = "librtmp/handshake.h"
s = open(p, encoding="utf-8", errors="surrogateescape").read()
old = ("#define HMAC_setup(ctx, key, len)\tHMAC_CTX_init(&ctx); HMAC_Init_ex(&ctx, key, len, EVP_sha256(), 0)\n"
       "#define HMAC_crunch(ctx, buf, len)\tHMAC_Update(&ctx, buf, len)\n"
       "#define HMAC_finish(ctx, dig, dlen)\tHMAC_Final(&ctx, dig, &dlen); HMAC_CTX_cleanup(&ctx)")
new = ("#define HMAC_setup(ctx, key, len)\tctx = HMAC_CTX_new(); HMAC_Init_ex(ctx, key, len, EVP_sha256(), 0)\n"
       "#define HMAC_crunch(ctx, buf, len)\tHMAC_Update(ctx, buf, len)\n"
       "#define HMAC_finish(ctx, dig, dlen)\tHMAC_Final(ctx, dig, &dlen); HMAC_CTX_free(ctx)")
assert old in s, "handshake HMAC block not found"
s = s.replace(old, new)
n = s.count("  HMAC_CTX ctx;")
s = s.replace("  HMAC_CTX ctx;", "  HMAC_CTX *ctx;")
open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("handshake.h patched, %d field(s)" % n)
PYEOF

git diff > /g/deps-build/patches/librtmp-openssl3.patch
echo done
