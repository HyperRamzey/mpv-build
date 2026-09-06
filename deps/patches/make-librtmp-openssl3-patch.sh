#!/bin/bash
# make-librtmp-openssl3-patch.sh — one-shot: patch rtmpdump for OpenSSL 3 in the
# deps-build clone and emit patches/librtmp-openssl3.patch
set -e
cd /g/deps-build/src/librtmp

python - <<'PYEOF'
p = "librtmp/hashswf.c"
s = open(p, encoding="utf-8", errors="surrogateescape").read()
old = ("#define HMAC_setup(ctx, key, len)\tHMAC_CTX_init(&ctx); HMAC_Init_ex(&ctx, (unsigned char *)key, len, EVP_sha256(), 0)\n"
       "#define HMAC_crunch(ctx, buf, len)\tHMAC_Update(&ctx, (unsigned char *)buf, len)\n"
       "#define HMAC_finish(ctx, dig, dlen)\tHMAC_Final(&ctx, (unsigned char *)dig, &dlen);\n"
       "#define HMAC_close(ctx)\tHMAC_CTX_cleanup(&ctx)")
new = ("#define HMAC_setup(ctx, key, len)\tctx = HMAC_CTX_new(); HMAC_Init_ex(ctx, (unsigned char *)key, len, EVP_sha256(), 0)\n"
       "#define HMAC_crunch(ctx, buf, len)\tHMAC_Update(ctx, (unsigned char *)buf, len)\n"
       "#define HMAC_finish(ctx, dig, dlen)\tHMAC_Final(ctx, (unsigned char *)dig, &dlen); HMAC_CTX_free(ctx)\n"
       "#define HMAC_close(ctx)")
assert old in s, "hashswf HMAC block not found"
s = s.replace(old, new)
s = s.replace("  HMAC_CTX ctx;", "  HMAC_CTX *ctx;")
open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("hashswf.c patched")
PYEOF

python - <<'PYEOF'
p = "librtmp/dh.h"
s = open(p, encoding="utf-8", errors="surrogateescape").read()
old = """#define MDH\tDH
#define MDH_new()\tDH_new()
#define MDH_free(dh)\tDH_free(dh)
#define MDH_generate_key(dh)\tDH_generate_key(dh)
#define MDH_compute_key(secret, seclen, pub, dh)\tDH_compute_key(secret, pub, dh)

#endif
"""
new = """/* OpenSSL >= 1.1 made DH opaque; keep our own mirror struct (like the GnuTLS
 * path above) and sync through the accessors. */
typedef struct MDH {
  MP_t p;
  MP_t g;
  MP_t pub_key;
  MP_t priv_key;
  long length;
  DH *sysdh;
} MDH;

#define\tMDH_new()\tcalloc(1,sizeof(MDH))
#define MDH_free(dh)\tdo {MP_free(((MDH*)(dh))->p); MP_free(((MDH*)(dh))->g); MP_free(((MDH*)(dh))->pub_key); MP_free(((MDH*)(dh))->priv_key); if (((MDH*)(dh))->sysdh) DH_free(((MDH*)(dh))->sysdh); free(dh);} while(0)

static int MDH_generate_key(MDH *dh)
{
  const BIGNUM *pub = NULL, *priv = NULL;
  if (!dh->sysdh)
    {
      dh->sysdh = DH_new();
      if (!dh->sysdh)
        return 0;
      if (!DH_set0_pqg(dh->sysdh, dh->p, NULL, dh->g))
        return 0;
      dh->p = NULL;         /* ownership moved into sysdh */
      dh->g = NULL;
      DH_set_length(dh->sysdh, dh->length);
    }
  if (!DH_generate_key(dh->sysdh))
    return 0;
  DH_get0_key(dh->sysdh, &pub, &priv);
  if (dh->pub_key)
    BN_clear_free(dh->pub_key);
  if (dh->priv_key)
    BN_clear_free(dh->priv_key);
  dh->pub_key = BN_dup(pub);
  dh->priv_key = BN_dup(priv);
  return dh->pub_key && dh->priv_key;
}

static int MDH_compute_key(uint8_t *secret, size_t len, MP_t pub, MDH *dh)
{
  if (!dh->sysdh)
    return -1;
  return DH_compute_key(secret, pub, dh->sysdh);
}

#endif
"""
assert old in s, "dh.h OpenSSL block not found"
s = s.replace(old, new)
# safe MP_gethex for our calloc'd mirror (u starts NULL anyway, keep semantics)
open(p, "w", encoding="utf-8", errors="surrogateescape").write(s)
print("dh.h patched")
PYEOF

git diff > /g/deps-build/patches/librtmp-openssl3.patch
echo "patch written: $(grep -c '^+' /g/deps-build/patches/librtmp-openssl3.patch) added lines"
