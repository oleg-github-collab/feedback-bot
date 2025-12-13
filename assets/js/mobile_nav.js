/**
 * Mobile Navigation - Burger Menu
 * Touch-optimized navigation with smooth animations
 */

export const MobileNav = {
  mounted() {
    this.isOpen = false
    this.burgers = Array.from(this.el.querySelectorAll('[data-burger]'))
    this.menu = this.el.querySelector('[data-mobile-menu]')
    this.backdrop = this.el.querySelector('[data-backdrop]')
    this.links = this.el.querySelectorAll('[data-mobile-link]')

    // Burger button click
    this.burgers.forEach(btn => btn.addEventListener('click', () => this.toggle()))

    // Backdrop click to close
    if (this.backdrop) {
      this.backdrop.addEventListener('click', () => this.close())
    }

    // Close on link click
    this.links.forEach(link => {
      link.addEventListener('click', () => this.close())
    })

    // Close on escape key
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.isOpen) {
        this.close()
      }
    })

    // Prevent scroll when menu open
    this.onScrollLock = () => {
      document.body.style.overflow = this.isOpen ? 'hidden' : ''
    }
  },

  toggle() {
    this.isOpen ? this.close() : this.open()
  },

  open() {
    this.isOpen = true
    this.menu?.classList.remove('translate-x-full')
    this.menu?.classList.add('translate-x-0')
    this.backdrop?.classList.remove('opacity-0', 'pointer-events-none')
    this.backdrop?.classList.add('opacity-100')
    document.body.style.overflow = 'hidden'
    document.documentElement.classList.add('mobile-menu-open')
    document.body.classList.add('mobile-menu-open')

    // Animate burger to X
    this.burgers.forEach(burger => {
      const lines = burger.querySelectorAll('span')
      if (lines.length === 3) {
        lines[0].style.transform = 'rotate(45deg) translateY(8px)'
        lines[1].style.opacity = '0'
        lines[2].style.transform = 'rotate(-45deg) translateY(-8px)'
      }
    })
  },

  close() {
    this.isOpen = false
    this.menu?.classList.remove('translate-x-0')
    this.menu?.classList.add('translate-x-full')
    this.backdrop?.classList.remove('opacity-100')
    this.backdrop?.classList.add('opacity-0', 'pointer-events-none')

    setTimeout(() => {
      document.body.style.overflow = ''
      document.documentElement.classList.remove('mobile-menu-open')
      document.body.classList.remove('mobile-menu-open')
    }, 300)

    // Reset burger animation
    this.burgers.forEach(burger => {
      const lines = burger.querySelectorAll('span')
      if (lines.length === 3) {
        lines[0].style.transform = ''
        lines[1].style.opacity = '1'
        lines[2].style.transform = ''
      }
    })
  },

  destroyed() {
    document.body.style.overflow = ''
    document.documentElement.classList.remove('mobile-menu-open')
    document.body.classList.remove('mobile-menu-open')
  }
}
