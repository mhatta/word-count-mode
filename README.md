# word-count-mode

Shows the number of words/characters of the current buffer in the mode line.

# Usage

Put something like this in your init.el:

``` emacs-lisp
(autoload 'word-count-mode "word-count"
	"Minor mode to count words." t nil)
(global-set-key "\M-+" 'word-count-mode)
```

Then

* M-+ (word-count-mode) toggles word-count mode.
* M-[space] (word-count-set-area) sets area for counting words.
* M-x word-count-set-region sets region or paragraph for counting words.
* M-x word-count-set-marker sets marker for counting words.

# Author and Maintainers

This emacs lisp was originally written by Hiroyuki Komatsu (@hiroyuki-komatsu) years ago.  The upstream site has long gone, but you can still see the original version using Wayback Machine: [http://web.archive.org/web/20100924082154/http://taiyaki.org/elisp/word-count/src/word-count.el](http://web.archive.org/web/20100924082154/http://taiyaki.org/elisp/word-count/src/word-count.el).

Tomasz Skutnik (@tomaszskutnik) salvaged and updated word-count-mode for Emacs24.  Masayuki Hatta (@mhatta) updated it for Emacs26 and prepared for MELPA.

# License

 Licensed under the same terms as Emacs.

(word-count-mode was originally released under GPL2, but changed license with the blessing of the original author).
