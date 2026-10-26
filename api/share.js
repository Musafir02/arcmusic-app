// Share pages for https://arcmusic-app.vercel.app/s/<id>.
//
// Reads the public snapshot from the Firestore `shares` collection (the rules
// allow a public read by random id) and renders a page with dynamic Open
// Graph tags, so WhatsApp and other apps show the shared song or playlist
// name, song count and cover art before anyone taps the link.

const PROJECT = 'arcmusic-4d9a1';
const API_KEY = 'AIzaSyC_KPaYLGlcyhHonBWtNdIjjUON9RQOvqY';
const SHARE_ID = /^[a-z0-9]{8}$/;
const SITE = 'https://arcmusic-app.vercel.app';
const DEFAULT_OG_IMAGE = `${SITE}/og-image.png`;
const ANDROID_PACKAGE = 'com.arcmusic.arcmusic';
const RELEASES_PAGE = 'https://github.com/Musafir02/arcmusic-app/releases/latest';
const GITHUB_API = 'https://api.github.com/repos/Musafir02/arcmusic-app/releases/latest';
const MAX_LISTED_SONGS = 50;

const STYLE = `
    :root {
        --void: #080707;
        --ember: #d97757;
        --card: rgba(20, 19, 18, 0.6);
        --border: rgba(217, 119, 87, 0.15);
    }
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
        min-height: 100vh;
        display: flex;
        flex-direction: column;
        background-color: var(--void);
        background-image:
            radial-gradient(circle at 50% -20%, rgba(217, 119, 87, 0.18), transparent 75%),
            linear-gradient(rgba(255, 255, 255, 0.007) 1px, transparent 1px),
            linear-gradient(90deg, rgba(255, 255, 255, 0.007) 1px, transparent 1px);
        background-size: 100% 100%, 50px 50px, 50px 50px;
        color: #ffffff;
        font-family: 'Urbanist', sans-serif;
        line-height: 1.6;
    }
    header { padding: 28px 24px; display: flex; justify-content: center; }
    .logo {
        display: inline-flex;
        align-items: center;
        gap: 10px;
        font-family: 'Bricolage Grotesque', sans-serif;
        font-size: 24px;
        font-weight: 800;
        letter-spacing: -0.5px;
        color: #ffffff;
        text-decoration: none;
    }
    .logo img { height: 28px; width: auto; display: block; flex-shrink: 0; }
    main {
        flex: 1;
        width: 100%;
        max-width: 560px;
        margin: 0 auto;
        padding: 16px 24px 64px;
        display: flex;
        flex-direction: column;
        align-items: center;
        text-align: center;
    }
    .badge {
        background: rgba(217, 119, 87, 0.12);
        border: 1px solid rgba(217, 119, 87, 0.3);
        color: var(--ember);
        padding: 4px 12px;
        border-radius: 100px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.5px;
        text-transform: uppercase;
        margin-bottom: 28px;
    }
    .cover {
        width: min(62vw, 260px);
        aspect-ratio: 1;
        border-radius: 20px;
        object-fit: cover;
        border: 1px solid var(--border);
        box-shadow: 0 24px 60px rgba(217, 119, 87, 0.22), 0 8px 24px rgba(0, 0, 0, 0.5);
        margin-bottom: 28px;
        background: var(--card);
    }
    h1 {
        font-family: 'Bricolage Grotesque', sans-serif;
        font-size: 30px;
        font-weight: 800;
        letter-spacing: -0.5px;
        line-height: 1.2;
        margin-bottom: 8px;
    }
    .meta {
        color: rgba(255, 255, 255, 0.65);
        font-size: 15px;
        font-weight: 600;
        margin-bottom: 32px;
        max-width: 420px;
    }
    .actions { width: 100%; display: flex; flex-direction: column; gap: 12px; }
    .btn {
        display: block;
        width: 100%;
        padding: 16px 24px;
        border-radius: 100px;
        font-size: 16px;
        font-weight: 700;
        text-decoration: none;
        text-align: center;
        transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1), background-color 0.3s ease, border-color 0.3s ease;
    }
    .btn-primary {
        background: var(--ember);
        color: #ffffff;
        box-shadow: 0 10px 25px rgba(217, 119, 87, 0.25);
    }
    .btn-primary:hover { transform: translateY(-2px); background: #e28769; }
    .btn-ghost {
        background: var(--card);
        border: 1px solid var(--border);
        color: #ffffff;
    }
    .btn-ghost:hover { transform: translateY(-2px); border-color: rgba(217, 119, 87, 0.45); }
    .hint {
        display: none;
        color: rgba(255, 255, 255, 0.5);
        font-size: 13px;
        margin-top: 14px;
    }
    .songs {
        width: 100%;
        margin-top: 40px;
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 6px 20px;
        text-align: left;
    }
    .song {
        display: flex;
        align-items: center;
        gap: 14px;
        padding: 12px 0;
        border-bottom: 1px solid rgba(255, 255, 255, 0.05);
    }
    .song:last-child { border-bottom: none; }
    .song .num {
        color: rgba(255, 255, 255, 0.35);
        font-size: 13px;
        font-weight: 700;
        width: 20px;
        text-align: right;
        flex-shrink: 0;
    }
    .song .t { display: block; min-width: 0; }
    .song .n {
        display: block;
        font-size: 14px;
        font-weight: 700;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }
    .song .a {
        display: block;
        font-size: 12px;
        color: rgba(255, 255, 255, 0.55);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }
    .more { color: rgba(255, 255, 255, 0.45); font-size: 13px; padding: 12px 0; }
    footer { padding: 24px; text-align: center; color: rgba(255, 255, 255, 0.35); font-size: 13px; }
    @media (max-width: 420px) { h1 { font-size: 26px; } }
`;

function esc(value) {
    return String(value == null ? '' : value).replace(/[&<>"']/g, (c) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#39;',
    }[c]));
}

function decodeField(field) {
    if (!field || typeof field !== 'object') return null;
    if ('stringValue' in field) return field.stringValue;
    if ('integerValue' in field) return Number(field.integerValue);
    if ('doubleValue' in field) return field.doubleValue;
    if ('booleanValue' in field) return !!field.booleanValue;
    if ('timestampValue' in field) return field.timestampValue;
    if ('arrayValue' in field) return (field.arrayValue.values || []).map(decodeField);
    if ('mapValue' in field) return decodeFields(field.mapValue.fields || {});
    return null;
}

function decodeFields(fields) {
    const out = {};
    for (const key of Object.keys(fields)) out[key] = decodeField(fields[key]);
    return out;
}

function parseShare(data) {
    if (!data) return null;
    const type = data.type === 'playlist' ? 'playlist' : data.type === 'song' ? 'song' : null;
    if (!type) return null;

    const songs = (Array.isArray(data.songs) ? data.songs : [])
        .filter((s) => s && typeof s === 'object' && s.id)
        .map((s) => ({
            id: String(s.id),
            name: String(s.name || ''),
            artist: String(s.artist || ''),
            image: String(s.image || ''),
        }));
    if (!songs.length) return null;

    let image = String(data.image || '');
    if (!image) {
        const withArt = songs.find((s) => s.image);
        image = withArt ? withArt.image : '';
    }

    return {
        type,
        name: String(data.name || 'Shared on ArcMusic'),
        artist: String(data.artist || ''),
        image,
        songs,
    };
}

async function fetchShare(id) {
    const url = `${'https://firestore.googleapis.com/v1/projects/'}${PROJECT}` +
        `/databases/(default)/documents/shares/${id}?key=${API_KEY}`;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    try {
        const res = await fetch(url, { signal: controller.signal });
        if (res.status === 404) return null;
        if (!res.ok) throw new Error('firestore ' + res.status);
        const doc = await res.json();
        return parseShare(decodeFields(doc.fields || {}));
    } finally {
        clearTimeout(timer);
    }
}

function shellHtml({ title, ogTitle, ogDescription, ogUrl, ogImage, noindex, bodyHtml, scriptHtml }) {
    const image = ogImage || DEFAULT_OG_IMAGE;
    const imageTags = `    <meta property="og:image" content="${esc(image)}">
    <meta property="og:image:alt" content="${esc(ogTitle)}">
    <meta name="twitter:image" content="${esc(image)}">`;
    return `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${esc(title)}</title>
    <meta name="description" content="${esc(ogDescription)}">
    <link rel="canonical" href="${esc(ogUrl)}">
    <link rel="icon" type="image/svg+xml" href="/favicon.svg">
    <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32.png">
    <link rel="apple-touch-icon" href="/apple-touch-icon.png">
    <meta property="og:site_name" content="ArcMusic">
    <meta property="og:type" content="website">
    <meta property="og:title" content="${esc(ogTitle)}">
    <meta property="og:description" content="${esc(ogDescription)}">
    <meta property="og:url" content="${esc(ogUrl)}">
${imageTags}
    <meta name="twitter:card" content="summary_large_image">
    ${noindex ? '<meta name="robots" content="noindex">' : ''}
    <meta name="theme-color" content="#080707">
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Bricolage+Grotesque:opsz,wght@12..96,200..800&family=Urbanist:ital,wght@0,100..900;1,100..900&display=swap" rel="stylesheet">
    <style>${STYLE}</style>
</head>
<body>
    <header><a class="logo" href="/"><img src="/brand-mark.svg" alt="">ArcMusic</a></header>
    <main>
${bodyHtml}
    </main>
    <footer>&copy; 2026 ArcMusic</footer>
${scriptHtml}
</body>
</html>`;
}

function renderShare(share, id) {
    const isPlaylist = share.type === 'playlist';
    const count = share.songs.length;
    const url = `${SITE}/s/${id}`;

    const metaLine = isPlaylist
        ? `${count} ${count === 1 ? 'song' : 'songs'} · listen on ArcMusic`
        : `${share.artist} · listen on ArcMusic`;
    const ogTitle = isPlaylist
        ? `🎧 ${share.name} · ${count} songs`
        : `🎵 ${share.name} — ${share.artist}`;
    let ogDescription;
    if (isPlaylist) {
        const names = share.songs.slice(0, 6).map((s) => s.name).filter(Boolean).join(', ');
        ogDescription = names ? `${names}${count > 6 ? '…' : ''}` : 'A playlist on ArcMusic';
    } else {
        ogDescription = `${share.artist} on ArcMusic`;
    }

    const cover = share.image
        ? `<img class="cover" src="${esc(share.image)}" alt="" onerror="this.remove()">`
        : '';

    let list = '';
    if (isPlaylist) {
        const shown = share.songs.slice(0, MAX_LISTED_SONGS);
        const rows = shown.map((s, i) =>
            `<div class="song"><span class="num">${i + 1}</span>` +
            `<span class="t"><span class="n">${esc(s.name)}</span>` +
            `<span class="a">${esc(s.artist)}</span></span></div>`
        ).join('\n            ');
        const more = count > shown.length
            ? `\n            <div class="more">+ ${count - shown.length} more songs</div>`
            : '';
        list = `        <div class="songs">
            ${rows}${more}
        </div>`;
    }

    const bodyHtml = `        <span class="badge">${isPlaylist ? 'Shared playlist' : 'Shared song'}</span>
        ${cover}
        <h1>${esc(share.name)}</h1>
        <p class="meta">${esc(metaLine)}</p>
        <div class="actions">
            <a id="open-btn" class="btn btn-primary" href="arcmusic://s/${id}">Open in ArcMusic</a>
            <a id="dl-btn" class="btn btn-ghost" href="${RELEASES_PAGE}">Download ArcMusic</a>
        </div>
        <p class="hint" id="hint">App didn't open? Tap "Download ArcMusic" to install it.</p>
${list}`;

    const scriptHtml = `<script>
    (function () {
        var id = '${id}';
        var dl = document.getElementById('dl-btn');
        var hint = document.getElementById('hint');
        document.getElementById('open-btn').addEventListener('click', function () {
            var ua = navigator.userAgent || '';
            if (/android/i.test(ua)) {
                window.location.href = 'intent://s/' + id +
                    '#Intent;scheme=arcmusic;package=${ANDROID_PACKAGE};S.browser_fallback_url=' +
                    encodeURIComponent(dl.href) + ';end';
            } else {
                window.location.href = 'arcmusic://s/' + id;
            }
            setTimeout(function () { hint.style.display = 'block'; }, 1800);
        });
        fetch('${GITHUB_API}').then(function (r) {
            return r.json();
        }).then(function (d) {
            var assets = (d && d.assets) || [];
            var apk = assets.filter(function (a) { return /arm64-v8a/.test(a.name); })[0] || assets[0];
            if (apk) dl.href = apk.browser_download_url;
        }).catch(function () {});
    })();
</script>`;

    return shellHtml({
        title: ogTitle,
        ogTitle,
        ogDescription,
        ogUrl: url,
        ogImage: share.image,
        noindex: false,
        bodyHtml,
        scriptHtml,
    });
}

function renderNotFound() {
    return shellHtml({
        title: 'Link not found — ArcMusic',
        ogTitle: 'Link not found — ArcMusic',
        ogDescription: 'This ArcMusic share link is not available.',
        ogUrl: SITE + '/',
        ogImage: '',
        noindex: true,
        bodyHtml: `        <span class="badge">Share link</span>
        <h1>This link is not available</h1>
        <p class="meta">It may have been mistyped or removed. Ask the sender for a fresh link.</p>
        <div class="actions">
            <a class="btn btn-primary" href="${RELEASES_PAGE}">Download ArcMusic</a>
            <a class="btn btn-ghost" href="/">Visit homepage</a>
        </div>`,
        scriptHtml: '',
    });
}

function renderError() {
    return shellHtml({
        title: 'ArcMusic',
        ogTitle: 'ArcMusic — share link',
        ogDescription: 'ArcMusic share link.',
        ogUrl: SITE + '/',
        ogImage: '',
        noindex: true,
        bodyHtml: `        <span class="badge">Share link</span>
        <h1>This share could not load</h1>
        <p class="meta">Something went wrong on our side. Try again in a moment.</p>
        <div class="actions">
            <a class="btn btn-primary" href="">Try again</a>
            <a class="btn btn-ghost" href="/">Visit homepage</a>
        </div>`,
        scriptHtml: '',
    });
}

function sendHtml(res, status, cacheControl, html) {
    res.statusCode = status;
    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    res.setHeader('Cache-Control', cacheControl);
    res.end(html);
}

function idFromRequest(req) {
    const query = req.query || {};
    if (query.id) return String(query.id);
    try {
        const url = new URL(req.url || '/', SITE);
        const direct = url.searchParams.get('id');
        if (direct) return direct;
        const parts = url.pathname.split('/').filter(Boolean);
        return parts.length ? parts[parts.length - 1] : '';
    } catch (_) {
        return '';
    }
}

module.exports = async function handler(req, res) {
    const id = idFromRequest(req).trim().toLowerCase();

    if (!SHARE_ID.test(id)) {
        return sendHtml(res, 404, 'public, max-age=0, s-maxage=300', renderNotFound());
    }

    let share;
    try {
        share = await fetchShare(id);
    } catch (_) {
        return sendHtml(res, 503, 'no-store', renderError());
    }

    if (!share) {
        return sendHtml(res, 404, 'public, max-age=0, s-maxage=300', renderNotFound());
    }

    return sendHtml(res, 200, 'public, max-age=0, s-maxage=86400', renderShare(share, id));
};
