// Presentation JavaScript
let currentSlide = 1;
const totalSlides = 11;

// Initialize presentation
document.addEventListener('DOMContentLoaded', function() {
    showSlide(currentSlide);
    updateSlideCounter();
    
    // Keyboard navigation
    document.addEventListener('keydown', function(e) {
        if (e.key === 'ArrowRight' || e.key === ' ') {
            changeSlide(1);
        } else if (e.key === 'ArrowLeft') {
            changeSlide(-1);
        } else if (e.key === 'Home') {
            goToSlide(1);
        } else if (e.key === 'End') {
            goToSlide(totalSlides);
        }
    });
    
    // Touch/swipe support for mobile
    let startX = 0;
    let endX = 0;
    
    document.addEventListener('touchstart', function(e) {
        startX = e.touches[0].clientX;
    });
    
    document.addEventListener('touchend', function(e) {
        endX = e.changedTouches[0].clientX;
        handleSwipe();
    });
    
    function handleSwipe() {
        const swipeThreshold = 50;
        const diff = startX - endX;
        
        if (Math.abs(diff) > swipeThreshold) {
            if (diff > 0) {
                // Swipe left - next slide
                changeSlide(1);
            } else {
                // Swipe right - previous slide
                changeSlide(-1);
            }
        }
    }
});

function changeSlide(direction) {
    const newSlide = currentSlide + direction;
    
    if (newSlide >= 1 && newSlide <= totalSlides) {
        currentSlide = newSlide;
        showSlide(currentSlide);
        updateSlideCounter();
        updateNavigationButtons();
    }
}

function goToSlide(slideNumber) {
    if (slideNumber >= 1 && slideNumber <= totalSlides) {
        currentSlide = slideNumber;
        showSlide(currentSlide);
        updateSlideCounter();
        updateNavigationButtons();
    }
}

function showSlide(slideNumber) {
    // Hide all slides
    const slides = document.querySelectorAll('.slide');
    slides.forEach(slide => {
        slide.classList.remove('active');
    });
    
    // Show current slide
    const currentSlideElement = document.getElementById(`slide${slideNumber}`);
    if (currentSlideElement) {
        currentSlideElement.classList.add('active');
    }
    
    // Add slide transition animation
    currentSlideElement.style.opacity = '0';
    setTimeout(() => {
        currentSlideElement.style.opacity = '1';
    }, 50);
}

function updateSlideCounter() {
    const counter = document.getElementById('slideCounter');
    if (counter) {
        counter.textContent = `${currentSlide} / ${totalSlides}`;
    }
}

function updateNavigationButtons() {
    const prevBtn = document.getElementById('prevBtn');
    const nextBtn = document.getElementById('nextBtn');
    
    if (prevBtn) {
        prevBtn.disabled = currentSlide === 1;
    }
    
    if (nextBtn) {
        nextBtn.disabled = currentSlide === totalSlides;
    }
}

// Presentation mode toggle
function toggleFullscreen() {
    if (!document.fullscreenElement) {
        document.documentElement.requestFullscreen().catch(err => {
            console.log(`Error attempting to enable fullscreen: ${err.message}`);
        });
    } else {
        document.exitFullscreen();
    }
}

// Add fullscreen toggle on F11 or F key
document.addEventListener('keydown', function(e) {
    if (e.key === 'F11' || e.key === 'f') {
        e.preventDefault();
        toggleFullscreen();
    }
});

// Auto-advance slides (optional - can be enabled for demo mode)
let autoAdvance = false;
let autoAdvanceInterval;

function startAutoAdvance(intervalSeconds = 30) {
    if (autoAdvance) return;
    
    autoAdvance = true;
    autoAdvanceInterval = setInterval(() => {
        if (currentSlide < totalSlides) {
            changeSlide(1);
        } else {
            stopAutoAdvance();
        }
    }, intervalSeconds * 1000);
}

function stopAutoAdvance() {
    autoAdvance = false;
    if (autoAdvanceInterval) {
        clearInterval(autoAdvanceInterval);
    }
}

// Toggle auto-advance with 'a' key
document.addEventListener('keydown', function(e) {
    if (e.key === 'a' || e.key === 'A') {
        if (autoAdvance) {
            stopAutoAdvance();
            console.log('Auto-advance stopped');
        } else {
            startAutoAdvance(10); // 10 seconds per slide
            console.log('Auto-advance started');
        }
    }
});

// Slide overview mode (show all slides in grid)
let overviewMode = false;

function toggleOverview() {
    const container = document.querySelector('.presentation-container');
    
    if (!overviewMode) {
        // Enter overview mode
        overviewMode = true;
        container.classList.add('overview-mode');
        
        // Show all slides in grid
        const slides = document.querySelectorAll('.slide');
        slides.forEach((slide, index) => {
            slide.classList.add('overview-slide');
            slide.style.display = 'block';
            slide.addEventListener('click', () => {
                exitOverview();
                goToSlide(index + 1);
            });
        });
    } else {
        exitOverview();
    }
}

function exitOverview() {
    overviewMode = false;
    const container = document.querySelector('.presentation-container');
    container.classList.remove('overview-mode');
    
    const slides = document.querySelectorAll('.slide');
    slides.forEach(slide => {
        slide.classList.remove('overview-slide');
        slide.style.display = 'none';
        slide.removeEventListener('click', () => {});
    });
    
    showSlide(currentSlide);
}

// Toggle overview with 'o' key
document.addEventListener('keydown', function(e) {
    if (e.key === 'o' || e.key === 'O') {
        toggleOverview();
    }
});

// Print presentation
function printPresentation() {
    // Show all slides for printing
    const slides = document.querySelectorAll('.slide');
    slides.forEach(slide => {
        slide.style.display = 'block';
    });
    
    window.print();
    
    // Restore normal view after printing
    setTimeout(() => {
        slides.forEach(slide => {
            slide.style.display = 'none';
        });
        showSlide(currentSlide);
    }, 1000);
}

// Print with Ctrl+P
document.addEventListener('keydown', function(e) {
    if (e.ctrlKey && e.key === 'p') {
        e.preventDefault();
        printPresentation();
    }
});

// Help overlay
function showHelp() {
    const helpOverlay = document.createElement('div');
    helpOverlay.className = 'help-overlay';
    helpOverlay.innerHTML = `
        <div class="help-content">
            <h3>Presentation Controls</h3>
            <ul>
                <li><strong>→ / Space:</strong> Next slide</li>
                <li><strong>← :</strong> Previous slide</li>
                <li><strong>Home:</strong> First slide</li>
                <li><strong>End:</strong> Last slide</li>
                <li><strong>F11 / F:</strong> Toggle fullscreen</li>
                <li><strong>A:</strong> Toggle auto-advance</li>
                <li><strong>O:</strong> Overview mode</li>
                <li><strong>Ctrl+P:</strong> Print presentation</li>
                <li><strong>H:</strong> Show/hide help</li>
                <li><strong>Esc:</strong> Close help</li>
            </ul>
            <p>Click anywhere to close this help.</p>
        </div>
    `;
    
    helpOverlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: rgba(0, 0, 0, 0.8);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 2000;
        color: white;
    `;
    
    helpOverlay.querySelector('.help-content').style.cssText = `
        background: #2c3e50;
        padding: 30px;
        border-radius: 15px;
        max-width: 500px;
    `;
    
    helpOverlay.addEventListener('click', () => {
        document.body.removeChild(helpOverlay);
    });
    
    document.body.appendChild(helpOverlay);
}

// Show help with 'h' key
document.addEventListener('keydown', function(e) {
    if (e.key === 'h' || e.key === 'H') {
        showHelp();
    }
    
    if (e.key === 'Escape') {
        const helpOverlay = document.querySelector('.help-overlay');
        if (helpOverlay) {
            document.body.removeChild(helpOverlay);
        }
        
        if (overviewMode) {
            exitOverview();
        }
    }
});

// Initialize navigation buttons
updateNavigationButtons();