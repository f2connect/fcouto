// Entrega a URL e a chave PÚBLICA do Supabase a partir das variáveis
// que a integração oficial Supabase ↔ Vercel cria sozinha.
// Nunca devolve a chave secreta (service_role / sb_secret_).
module.exports = (req, res) => {
  const e = process.env;
  const url = e.NEXT_PUBLIC_SUPABASE_URL || e.SUPABASE_URL || '';
  const cand = [e.NEXT_PUBLIC_SUPABASE_ANON_KEY, e.SUPABASE_ANON_KEY,
    e.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY, e.SUPABASE_PUBLISHABLE_KEY];
  const publica = (k) => {
    if (!k) return false;
    if (k.startsWith('sb_publishable_')) return true;
    if (!k.startsWith('eyJ')) return false;
    try {
      const p = JSON.parse(Buffer.from(k.split('.')[1], 'base64').toString());
      return p.role === 'anon';
    } catch (_) { return false; }
  };
  const key = cand.find(publica) || '';
  const c = {};
  if (url) c.supabaseUrl = url;
  if (key) c.supabaseAnonKey = key;
  res.setHeader('Content-Type', 'application/javascript; charset=utf-8');
  res.setHeader('Cache-Control', 'no-store');
  res.end('window.F2_CONFIG=Object.assign(window.F2_CONFIG||{},' + JSON.stringify(c) + ');');
};
