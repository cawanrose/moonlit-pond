import sys, os, zipfile
ver = sys.argv[1]            # e.g. 103 -> label 폴짝v103
src = '/home/claude/apk71'
out = f'/home/claude/build/MoonlitPond_v1_{ver[1:]}_unsigned.apk'
os.makedirs('/home/claude/build', exist_ok=True)
orig = zipfile.ZipFile('/mnt/user-data/uploads/Downloads/MoonlitPond_v0_71_update.apk')
order = [i.filename for i in orig.infolist()]
store = {i.filename for i in orig.infolist() if i.compress_type == zipfile.ZIP_STORED}
names = []
for r, _, fs in os.walk(src):
    for f in fs:
        n = os.path.relpath(os.path.join(r, f), src).replace(os.sep, '/')
        if n.startswith('META-INF/') and (n.endswith(('.SF', '.RSA', '.MF', '.EC'))):
            continue
        if '/_fishtest' in n: continue
        names.append(n)
names.sort(key=lambda n: (order.index(n) if n in order else 10**6, n))
def patch(n, d):
    if n in ('AndroidManifest.xml', 'resources.arsc'):
        for a, b in [('com.moonshot.moonlitpond.v30', 'com.moonshot.moonlitpond.v72'), ('폴짝 v71', '폴짝v' + ver)]:
            assert len(a) == len(b)
            d = d.replace(a.encode('utf-16le'), b.encode('utf-16le')).replace(a.encode(), b.encode())
    return d
with zipfile.ZipFile(out, 'w') as z:
    for n in names:
        d = patch(n, open(os.path.join(src, n), 'rb').read())
        ct = zipfile.ZIP_STORED if (n in store or n == 'resources.arsc') else zipfile.ZIP_DEFLATED
        zi = zipfile.ZipInfo(n, (1981, 1, 1, 1, 1, 2)); zi.compress_type = ct
        z.writestr(zi, d)
print(out, len(names))
