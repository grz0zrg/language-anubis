'use strict';

class BottomTab extends HTMLElement{

  initialize(Content, onClick) {
    this._active = false
    this.innerHTML = Content
    this.classList.add('anubis-language-build-tab')

    this.countSpan = document.createElement('span')
    this.countSpan.classList.add('count')
    this.countSpan.textContent = ''

    this.appendChild(document.createTextNode(' '))
    this.appendChild(this.countSpan)

    this.addEventListener('click', onClick)
  }
  get active() {
    return this._active
  }
  set active(value) {
    if (value) {
      this.classList.add('active')
    } else {
      this.classList.remove('active')
    }
    this._active = value
  }
  set count(value) {
    this._count = value
    this.countSpan.textContent = value
  }
  set visibility(value){
    if(value){
      this.removeAttribute('hidden')
    } else {
      this.setAttribute('hidden', true)
    }
  }
}

module.exports = BottomTab = document.registerElement('language-anubis-bottom-tab', {
  prototype: BottomTab.prototype
})
