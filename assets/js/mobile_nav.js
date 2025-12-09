/**
 * Mobile Navigation - Burger Menu
 * Touch-optimized navigation with smooth animations
 */

export const MobileNav = {
  mounted() {
    this.isOpen = false
    this.burger = this.el.querySelector('[data-burger]')
    this.menu = this.el.querySelector('[data-mobile-menu]')
    this.backdrop = this.el.querySelector('[data-backdrop]')
    this.links = this.el.querySelectorAll('[data-mobile-link]')

    // Burger button click
    if (this.burger) {
      this.burger.addEventListener('click', () => this.toggle())
    }

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

    // Animate burger to X
    const lines = this.burger?.querySelectorAll('span')
    if (lines && lines.length === 3) {
      lines[0].style.transform = 'rotate(45deg) translateY(8px)'
      lines[1].style.opacity = '0'
      lines[2].style.transform = 'rotate(-45deg) translateY(-8px)'
    }
  },

  close() {
    this.isOpen = false
    this.menu?.classList.remove('translate-x-0')
    this.menu?.classList.add('translate-x-full')
    this.backdrop?.classList.remove('opacity-100')
    this.backdrop?.classList.add('opacity-0', 'pointer-events-none')

    setTimeout(() => {
      document.body.style.overflow = ''
    }, 300)

    // Reset burger animation
    const lines = this.burger?.querySelectorAll('span')
    if (lines && lines.length === 3) {
      lines[0].style.transform = ''
      lines[1].style.opacity = '1'
      lines[2].style.transform = ''
    }
  },

  destroyed() {
    document.body.style.overflow = ''
  }
}
