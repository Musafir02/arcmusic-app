const repo = 'Musafir02/arcmusic-app';
const versionBadge = document.getElementById('version-badge');
const downloadArm64 = document.getElementById('download-arm64');
const downloadArm7 = document.getElementById('download-arm7');

let arm64Url = `https://github.com/${repo}/releases`;
let arm7Url = `https://github.com/${repo}/releases`;

async function fetchLatestRelease() {
    try {
        const response = await fetch(`https://api.github.com/repos/${repo}/releases/latest`);
        if (response.ok) {
            const data = await response.json();
            versionBadge.textContent = `Latest: ${data.tag_name}`;
            const assets = data.assets || [];
            const arm64 = assets.find(asset => asset.name.includes('arm64-v8a'));
            const arm7 = assets.find(asset => asset.name.includes('armeabi-v7a'));
            if (arm64) arm64Url = arm64.browser_download_url;
            if (arm7) arm7Url = arm7.browser_download_url;
        }
    } catch (_) {
    }
}

downloadArm64.addEventListener('click', (e) => {
    e.preventDefault();
    window.location.href = arm64Url;
});

downloadArm7.addEventListener('click', (e) => {
    e.preventDefault();
    window.location.href = arm7Url;
});

fetchLatestRelease();

const header = document.getElementById('site-header');
const onScroll = () => header.classList.toggle('scrolled', window.scrollY > 20);
window.addEventListener('scroll', onScroll, { passive: true });
onScroll();

const revealItems = document.querySelectorAll('.reveal');
if ('IntersectionObserver' in window) {
    const observer = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add('visible');
                observer.unobserve(entry.target);
            }
        });
    }, { threshold: 0.12 });
    revealItems.forEach((item) => observer.observe(item));
} else {
    revealItems.forEach((item) => item.classList.add('visible'));
}

const slides = Array.from(document.querySelectorAll('.carousel-slide'));
const prevBtn = document.getElementById('carousel-prev');
const nextBtn = document.getElementById('carousel-next');
const dotsContainer = document.getElementById('carousel-dots');
const wrapper = document.getElementById('carousel-wrapper');
const progressBar = document.getElementById('carousel-progress-bar');
const AUTO_DELAY = 4000;

let activeIndex = 0;
let autoSlideInterval = null;
let touchStartX = 0;
let touchEndX = 0;

function createDots() {
    dotsContainer.innerHTML = '';
    slides.forEach((_, index) => {
        const dot = document.createElement('div');
        dot.classList.add('carousel-dot');
        dot.setAttribute('role', 'button');
        dot.setAttribute('aria-label', `Go to screenshot ${index + 1}`);
        if (index === activeIndex) dot.classList.add('active');
        dot.addEventListener('click', () => goToSlide(index));
        dotsContainer.appendChild(dot);
    });
}

function restartProgress() {
    if (!progressBar) return;
    progressBar.style.transition = 'none';
    progressBar.style.width = '0%';
    void progressBar.offsetWidth;
    progressBar.style.transition = `width ${AUTO_DELAY}ms linear`;
    progressBar.style.width = '100%';
}

function updateCarousel() {
    const total = slides.length;
    slides.forEach((slide, i) => {
        let diff = i - activeIndex;
        if (diff < -total / 2) diff += total;
        if (diff > total / 2) diff -= total;

        slide.className = 'carousel-slide';
        if (diff === 0) slide.classList.add('active');
        else if (diff === 1) slide.classList.add('next-1');
        else if (diff === -1) slide.classList.add('prev-1');
        else if (diff === 2) slide.classList.add('next-2');
        else if (diff === -2) slide.classList.add('prev-2');
        else if (diff > 2) slide.classList.add('hidden-right');
        else slide.classList.add('hidden-left');
    });

    dotsContainer.querySelectorAll('.carousel-dot').forEach((dot, i) => {
        dot.classList.toggle('active', i === activeIndex);
    });
    restartProgress();
}

function goToSlide(index) {
    activeIndex = (index + slides.length) % slides.length;
    updateCarousel();
    resetAutoSlide();
}

function nextSlide() { goToSlide(activeIndex + 1); }
function prevSlide() { goToSlide(activeIndex - 1); }

function startAutoSlide() {
    autoSlideInterval = setInterval(nextSlide, AUTO_DELAY);
}

function resetAutoSlide() {
    clearInterval(autoSlideInterval);
    startAutoSlide();
}

prevBtn.addEventListener('click', prevSlide);
nextBtn.addEventListener('click', nextSlide);

slides.forEach((slide, index) => {
    slide.addEventListener('click', () => {
        if (index !== activeIndex) goToSlide(index);
    });
});

wrapper.addEventListener('mouseenter', () => clearInterval(autoSlideInterval));
wrapper.addEventListener('mouseleave', resetAutoSlide);

wrapper.addEventListener('touchstart', (e) => {
    touchStartX = e.changedTouches[0].screenX;
}, { passive: true });

wrapper.addEventListener('touchend', (e) => {
    touchEndX = e.changedTouches[0].screenX;
    const delta = touchEndX - touchStartX;
    if (Math.abs(delta) > 50) {
        if (delta < 0) nextSlide();
        else prevSlide();
    }
}, { passive: true });

document.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowRight') nextSlide();
    if (e.key === 'ArrowLeft') prevSlide();
});

createDots();
updateCarousel();
startAutoSlide();
