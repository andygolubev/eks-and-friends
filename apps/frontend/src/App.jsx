import React, { useState, useEffect } from 'react';

const API_URL = window.__RUNTIME_CONFIG__?.API_URL || '/api';
const AUTH_URL = window.__RUNTIME_CONFIG__?.AUTH_URL || '/auth';

const money = (cents) => `$${(cents / 100).toFixed(2)}`;

function App() {
  const [products, setProducts] = useState([]);
  const [cart, setCart] = useState({}); // { [productId]: qty }
  const [user, setUser] = useState(null);
  const [authError, setAuthError] = useState(null);
  const [notice, setNotice] = useState(null);
  const [form, setForm] = useState({ username: '', email: '', password: '', mode: 'login' });
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${API_URL}/products`)
      .then((res) => res.json())
      .then(setProducts)
      .catch((err) => setError(err.message));
  }, []);

  const addToCart = (id) =>
    setCart((c) => ({ ...c, [id]: (c[id] || 0) + 1 }));
  const removeFromCart = (id) =>
    setCart((c) => {
      const next = { ...c };
      if (next[id] > 1) next[id] -= 1;
      else delete next[id];
      return next;
    });

  const cartLines = Object.entries(cart)
    .map(([id, qty]) => {
      const p = products.find((p) => p.id === Number(id));
      return p ? { ...p, qty } : null;
    })
    .filter(Boolean);

  const cartTotal = cartLines.reduce((sum, l) => sum + l.price_cents * l.qty, 0);
  const cartCount = cartLines.reduce((sum, l) => sum + l.qty, 0);

  const submitAuth = async (e) => {
    e.preventDefault();
    setAuthError(null);
    const path = form.mode === 'register' ? 'register' : 'login';
    const payload =
      form.mode === 'register'
        ? { username: form.username, email: form.email, password: form.password }
        : { username: form.username, password: form.password };
    try {
      const res = await fetch(`${AUTH_URL}/${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
      const data = await res.json();
      if (!res.ok) {
        setAuthError(data.error || 'authentication failed');
        return;
      }
      setUser({ username: data.username, token: data.token });
    } catch (err) {
      setAuthError(err.message);
    }
  };

  const checkout = async () => {
    setNotice(null);
    if (cartLines.length === 0) return;
    try {
      const res = await fetch(`${API_URL}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          customer: user.username,
          items: cartLines.map((l) => ({ product_id: l.id, quantity: l.qty })),
        }),
      });
      const data = await res.json();
      if (!res.ok) {
        setNotice(`Checkout failed: ${data.error || 'error'}`);
        return;
      }
      setNotice(`✅ Order #${data.id} placed — total ${money(data.total_cents)}. Thanks, ${data.customer}!`);
      setCart({});
    } catch (err) {
      setNotice(`Checkout failed: ${err.message}`);
    }
  };

  return (
    <div style={S.page}>
      <header style={S.header}>
        <h1 style={{ margin: 0 }}>🛒 EKS Boutique</h1>
        <div style={S.headerRight}>
          {user ? (
            <span>
              Hi, <strong>{user.username}</strong>{' '}
              <button style={S.linkBtn} onClick={() => setUser(null)}>logout</button>
            </span>
          ) : (
            <span style={{ color: '#888' }}>not signed in</span>
          )}
          <span style={S.cartBadge}>Cart: {cartCount} · {money(cartTotal)}</span>
        </div>
      </header>

      {error && <p style={{ color: 'red' }}>Could not load products: {error}</p>}

      <div style={S.layout}>
        <main>
          <h2>Products</h2>
          <div style={S.grid}>
            {products.map((p) => (
              <div key={p.id} style={S.card}>
                <div style={S.emoji}>{p.emoji}</div>
                <div style={S.cardName}>{p.name}</div>
                <div style={S.cardCat}>{p.category}</div>
                <p style={S.cardDesc}>{p.description}</p>
                <div style={S.cardFooter}>
                  <strong>{money(p.price_cents)}</strong>
                  <button style={S.btn} onClick={() => addToCart(p.id)}>Add</button>
                </div>
              </div>
            ))}
            {products.length === 0 && !error && <p>Loading catalog…</p>}
          </div>
        </main>

        <aside style={S.aside}>
          {!user && (
            <div style={S.panel}>
              <h3 style={{ marginTop: 0 }}>
                {form.mode === 'register' ? 'Create account' : 'Sign in'}
              </h3>
              <form onSubmit={submitAuth}>
                <input
                  style={S.input}
                  placeholder="username"
                  value={form.username}
                  onChange={(e) => setForm({ ...form, username: e.target.value })}
                />
                {form.mode === 'register' && (
                  <input
                    style={S.input}
                    placeholder="email"
                    value={form.email}
                    onChange={(e) => setForm({ ...form, email: e.target.value })}
                  />
                )}
                <input
                  style={S.input}
                  type="password"
                  placeholder="password"
                  value={form.password}
                  onChange={(e) => setForm({ ...form, password: e.target.value })}
                />
                <button style={{ ...S.btn, width: '100%' }} type="submit">
                  {form.mode === 'register' ? 'Register' : 'Login'}
                </button>
              </form>
              {authError && <p style={{ color: 'red', fontSize: 13 }}>{authError}</p>}
              <p style={{ fontSize: 13 }}>
                {form.mode === 'register' ? 'Have an account? ' : 'No account? '}
                <button
                  style={S.linkBtn}
                  onClick={() =>
                    setForm({ ...form, mode: form.mode === 'register' ? 'login' : 'register' })
                  }
                >
                  {form.mode === 'register' ? 'Sign in' : 'Register'}
                </button>
              </p>
              <p style={{ fontSize: 12, color: '#888' }}>Demo login: demo / demo</p>
            </div>
          )}

          <div style={S.panel}>
            <h3 style={{ marginTop: 0 }}>Your cart</h3>
            {cartLines.length === 0 ? (
              <p style={{ color: '#888' }}>Cart is empty.</p>
            ) : (
              <>
                {cartLines.map((l) => (
                  <div key={l.id} style={S.cartLine}>
                    <span>{l.emoji} {l.name}</span>
                    <span style={S.qtyControls}>
                      <button style={S.qtyBtn} onClick={() => removeFromCart(l.id)}>−</button>
                      {l.qty}
                      <button style={S.qtyBtn} onClick={() => addToCart(l.id)}>+</button>
                    </span>
                    <span>{money(l.price_cents * l.qty)}</span>
                  </div>
                ))}
                <div style={S.cartTotal}>
                  <strong>Total</strong>
                  <strong>{money(cartTotal)}</strong>
                </div>
                {user ? (
                  <button style={{ ...S.btn, width: '100%' }} onClick={checkout}>
                    Checkout
                  </button>
                ) : (
                  <p style={{ fontSize: 13, color: '#888' }}>Sign in to check out.</p>
                )}
              </>
            )}
            {notice && <p style={{ fontSize: 13 }}>{notice}</p>}
          </div>
        </aside>
      </div>
    </div>
  );
}

const S = {
  page: { fontFamily: 'system-ui, sans-serif', maxWidth: 1100, margin: '1.5rem auto', padding: '0 1rem', color: '#1a1a1a' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '2px solid #eee', paddingBottom: '0.75rem' },
  headerRight: { display: 'flex', gap: '1rem', alignItems: 'center' },
  cartBadge: { background: '#1a73e8', color: '#fff', padding: '0.35rem 0.7rem', borderRadius: 20, fontSize: 14 },
  layout: { display: 'grid', gridTemplateColumns: '1fr 320px', gap: '1.5rem', marginTop: '1rem' },
  grid: { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: '1rem' },
  card: { border: '1px solid #e5e5e5', borderRadius: 12, padding: '1rem', display: 'flex', flexDirection: 'column', background: '#fff' },
  emoji: { fontSize: 48, textAlign: 'center' },
  cardName: { fontWeight: 600, marginTop: '0.5rem' },
  cardCat: { fontSize: 12, color: '#888', textTransform: 'uppercase', letterSpacing: 0.5 },
  cardDesc: { fontSize: 13, color: '#555', flexGrow: 1 },
  cardFooter: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '0.5rem' },
  aside: { display: 'flex', flexDirection: 'column', gap: '1rem' },
  panel: { border: '1px solid #e5e5e5', borderRadius: 12, padding: '1rem', background: '#fafafa' },
  input: { width: '100%', boxSizing: 'border-box', padding: '0.5rem', marginBottom: '0.5rem', borderRadius: 6, border: '1px solid #ccc' },
  btn: { background: '#1a73e8', color: '#fff', border: 'none', borderRadius: 6, padding: '0.45rem 0.8rem', cursor: 'pointer' },
  linkBtn: { background: 'none', border: 'none', color: '#1a73e8', cursor: 'pointer', padding: 0, textDecoration: 'underline' },
  qtyControls: { display: 'flex', alignItems: 'center', gap: '0.4rem' },
  qtyBtn: { width: 24, height: 24, borderRadius: 4, border: '1px solid #ccc', background: '#fff', cursor: 'pointer' },
  cartLine: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 14, marginBottom: '0.5rem', gap: '0.4rem' },
  cartTotal: { display: 'flex', justifyContent: 'space-between', borderTop: '1px solid #ddd', paddingTop: '0.5rem', margin: '0.5rem 0' },
};

export default App;
