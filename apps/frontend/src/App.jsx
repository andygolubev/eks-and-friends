import React, { useState, useEffect } from 'react';

const API_URL = window.__RUNTIME_CONFIG__?.API_URL || '/api';

function App() {
  const [health, setHealth] = useState(null);
  const [items, setItems] = useState([]);
  const [error, setError] = useState(null);

  useEffect(() => {
    fetch(`${API_URL}/health`)
      .then((res) => res.json())
      .then(setHealth)
      .catch((err) => setError(err.message));

    fetch(`${API_URL}/items`)
      .then((res) => res.json())
      .then(setItems)
      .catch(() => {});
  }, []);

  return (
    <div style={{ fontFamily: 'system-ui, sans-serif', maxWidth: 800, margin: '2rem auto', padding: '0 1rem' }}>
      <h1>EKS Demo App</h1>

      <section>
        <h2>Backend Health</h2>
        {error ? (
          <p style={{ color: 'red' }}>Error: {error}</p>
        ) : health ? (
          <pre style={{ background: '#f4f4f4', padding: '1rem', borderRadius: 8 }}>
            {JSON.stringify(health, null, 2)}
          </pre>
        ) : (
          <p>Loading...</p>
        )}
      </section>

      <section>
        <h2>Items</h2>
        {items.length > 0 ? (
          <ul>
            {items.map((item) => (
              <li key={item.id}>{item.name} - {item.description}</li>
            ))}
          </ul>
        ) : (
          <p>No items loaded yet.</p>
        )}
      </section>
    </div>
  );
}

export default App;
