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
            const version = data.tag_name;
            versionBadge.textContent = `Latest: ${version}`;
            const assets = data.assets;
            if (assets && assets.length > 0) {
                const arm64 = assets.find(asset => asset.name.includes('arm64-v8a'));
                const arm7 = assets.find(asset => asset.name.includes('armeabi-v7a'));
                if (arm64) {
                    arm64Url = arm64.browser_download_url;
                }
                if (arm7) {
                    arm7Url = arm7.browser_download_url;
                }
            }
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

const slides = Array.from(document.querySelectorAll('.carousel-slide'));
const prevBtn = document.getElementById('carousel-prev');
const nextBtn = document.getElementById('carousel-next');
const dotsContainer = document.getElementById('carousel-dots');
const wrapper = document.getElementById('carousel-wrapper');

let activeIndex = 0;
let autoSlideInterval = null;
let touchStartX = 0;
let touchEndX = 0;

function createDots() {
    dotsContainer.innerHTML = '';
    slides.forEach((_, index) => {
        const dot = document.createElement('div');
        dot.classList.add('carousel-dot');
        if (index === activeIndex) {
            dot.classList.add('active');
        }
        dot.addEventListener('click', () => {
            goToSlide(index);
        });
        dotsContainer.appendChild(dot);
    });
}

function updateCarousel() {
    const N = slides.length;
    slides.forEach((slide, i) => {
        let diff = i - activeIndex;
        if (diff < -N / 2) diff += N;
        if (diff > N / 2) diff -= N;
        
        slide.className = 'carousel-slide';
        
        if (diff === 0) {
            slide.classList.add('active');
        } else if (diff === 1) {
            slide.classList.add('next-1');
        } else if (diff === -1) {
            slide.classList.add('prev-1');
        } else if (diff === 2) {
            slide.classList.add('next-2');
        } else if (diff === -2) {
            slide.classList.add('prev-2');
        } else if (diff > 2) {
            slide.classList.add('hidden-right');
        } else {
            slide.classList.add('hidden-left');
        }
    });
    
    const dots = Array.from(dotsContainer.querySelectorAll('.carousel-dot'));
    dots.forEach((dot, i) => {
        dot.classList.toggle('active', i === activeIndex);
    });
}

function goToSlide(index) {
    const N = slides.length;
    activeIndex = (index + N) % N;
    updateCarousel();
    resetAutoSlide();
}

function nextSlide() {
    goToSlide(activeIndex + 1);
}

function prevSlide() {
    goToSlide(activeIndex - 1);
}

function startAutoSlide() {
    autoSlideInterval = setInterval(nextSlide, 4000);
}

function resetAutoSlide() {
    clearInterval(autoSlideInterval);
    startAutoSlide();
}

prevBtn.addEventListener('click', prevSlide);
nextBtn.addEventListener('click', nextSlide);

slides.forEach((slide, index) => {
    slide.addEventListener('click', () => {
        if (index !== activeIndex) {
            goToSlide(index);
        }
    });
});

wrapper.addEventListener('touchstart', (e) => {
    touchStartX = e.changedTouches[0].screenX;
}, { passive: true });

wrapper.addEventListener('touchend', (e) => {
    touchEndX = e.changedTouches[0].screenX;
    handleGesture();
}, { passive: true });

function handleGesture() {
    const delta = touchEndX - touchStartX;
    if (Math.abs(delta) > 50) {
        if (delta < 0) {
            nextSlide();
        } else {
            prevSlide();
        }
    }
}

createDots();
updateCarousel();
startAutoSlide();
