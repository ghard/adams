;;
;;  adams  -  Remote system administration tools
;;
;;  Copyright 2013,2014 Thomas de Grivel <thomas@lowh.net>
;;
;;  Permission to use, copy, modify, and distribute this software for any
;;  purpose with or without fee is hereby granted, provided that the above
;;  copyright notice and this permission notice appear in all copies.
;;
;;  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
;;  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;;  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
;;  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;;  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;;  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
;;  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
;;

(in-package :adams)

(in-re-readtable)

;;  Syntaxes

(define-syntax group<5> (name passwd
			 (#'parse-integer gid)
			 ((lambda (m) (cl-ppcre:split "," m)) members))
  #~|^([^:]*):([^:]*):([^:]*):([^:]*)$|
  "Syntax of the group permissions file /etc/group. See group(5).")

(define-syntax passwd<5> (name pass
			  (#'parse-integer uid gid)
			  realname home shell)
  #~|^([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*):([^:]*)$|
  "Syntax for the password file /etc/passwd. See passwd(5).")

(define-syntax ls<1>-lT (mode
			 (#'sh-parse-integer links)
			 owner
			 group
			 (#'sh-parse-integer size)
			 (#'chronicity:parse time)
			 name)
  #~|^([-a-zA-Z]{10})\s+([0-9]+)\s+(\S+)\s+(\S+)\s+([0-9]+)\s+(\S+ \S+ \S+ \S+)\s+(.+)$|
  "Syntax for `ls -lT` output. See ls(1)."
  (values name mode links owner group size time))

(define-syntax stat<1>-r ((#'sh-parse-integer
			   dev ino mode links uid gid rdev size)
			  (#'parse-unix-timestamp atime mtime ctime)
			  (#'sh-parse-integer blksize blocks flags)
			  file)
    #~|^([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) (.+)$|
  "Syntax for raw stat(1) output."
  (values file dev ino mode links uid gid rdev size
	  atime mtime ctime blksize blocks flags))

(define-syntax cksum<1>-legacy (sum size file)
    #~|(\S+) (\S+) (\S+)|
  "Syntax for cksum(1) legacy output.")

(define-syntax cksum<1> (algo sum file)
    #~|(\S+) \((.*)\) = (\S+)|
  "Syntax for cksum(1) output.")

(define-syntax mount<8> (device mp type options)
    #~|^\s*(\S+)\s+on\s+(\S+)\s+type\s+(\S+)\s+\(([^\)]+)\)|
  "Syntax for mount(8) list of mounted filesystems."
  (values device mp type (re-matches #~|[^\s,]+| options)))

(define-syntax fstab<5> (device mp type options freq passno)
    #~|^\s*([^\s#]+)\s+([^\s#]+)\s+([^\s#]+)\s+([^\s#]+)\s+([^\s#]+)\s+([^\s#]+)|
  "Syntax for /etc/fstab, see fstab(5)."
  (values device mp type
          (re-matches #~|[^,]+| options)
          (parse-integer freq)
          (parse-integer passno)))

(defun parse-ps-time (string)
  (or (re-bind #~|^\s*([0-9]+):([0-9]*\.[0-9]*)$| (d h) string
        (+ (* 3600 24 (the non-negative-fixnum (parse-integer d)))
           (truncate (* 3600 (parse-number h)))))
      (error "Invalid ps(1) time ?")))

(define-syntax ps<1>-u (user
                        (#'parse-number pid cpu mem vsz rss)
                        tt state
                        (#'chronicity:parse start)
                        (#'parse-ps-time time)
                        cmd)
    #~|^\s*(\S+)\s+([0-9]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9]+)\s+([0-9]+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$|
  "Syntax for ps -u, see ps(1).")