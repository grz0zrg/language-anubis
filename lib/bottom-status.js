'use strict';

class BottomStatus extends HTMLElement{

  initialize() {
    this.classList.add('inline-block')
    this.classList.add('linter-highlight')

    this.iconSpan = document.createElement('span')
    this.appendChild(this.iconSpan)

    this.count = 0
  }

  set count(Value) {
    if (Value) {
      this.classList.remove('status-success')
      this.iconSpan.classList.remove('icon-check')

      this.classList.add('status-error')
      this.iconSpan.classList.add('icon-x')

      this.iconSpan.textContent = Value === 1 ? '1 Issue' : `${Value} Issues`
    } else {
      this.classList.remove('status-error')
      this.iconSpan.classList.remove('icon-x')

      this.iconSpan.textContent = ''
    }
  }

}

module.exports = BottomStatus = document.registerElement('language-anubis-bottom-status', {prototype: BottomStatus.prototype})
