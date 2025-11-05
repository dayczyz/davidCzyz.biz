(async () => {
  const sources = {
    home: '/content/home.json',
    about: '/content/about.json'
  };

  // Decide which content file to fetch based on body data attribute
  const pageKey = document.body?.dataset?.cmsPage;
  if (!pageKey || !sources[pageKey]) return;

  try {
    const res = await fetch(sources[pageKey], { cache: 'no-store' });
    if (!res.ok) return;
    const data = await res.json();

    // Replace any element with [data-cms-key="..."]
    document.querySelectorAll('[data-cms-key]').forEach(el => {
      const key = el.getAttribute('data-cms-key');
      if (!(key in data)) return;

      // If element says markdown, render basic Markdown → HTML (very light)
      if (el.getAttribute('data-cms-format') === 'markdown') {
        el.innerHTML = data[key]
          .replace(/^### (.*$)/gim, '<h3>$1</h3>')
          .replace(/^## (.*$)/gim, '<h2>$1</h2>')
          .replace(/^# (.*$)/gim, '<h1>$1</h1>')
          .replace(/\*\*(.*?)\*\*/gim, '<strong>$1</strong>')
          .replace(/\*(.*?)\*/gim, '<em>$1</em>')
          .replace(/\n/g, '<br />');
      } else {
        el.textContent = data[key];
      }
    });
  } catch (e) {
    // fail silently on content fetch
  }
})();
