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

;;  Specified properties, what all specifications amount to.

(defmethod specified-property ((res resource)
			       (property symbol))
  (let ((value (get-property property (specified-properties res))))
    (if (eq +undefined+ value)
        (values nil value)
        value)))

(defmethod (setf specified-property) (value
				      (res resource)
				      (property symbol))
  (let ((p (specified-properties res)))
    (setf (get-property property p) value)
    (setf (specified-properties res) p)))

;;  Parse specifications

(defmethod parse-next-specification ((res resource) spec)
  (let ((property (pop spec))
	(value (pop spec)))
    (setf (specified-property res property) value)
    spec))

(defmethod parse-next-specification ((res resource-container) spec)
  (cond ((typep (first spec) 'resource)
	 (add-resource res (pop spec))
	 spec)
	(:otherwise (call-next-method))))

(defmethod parse-specification ((res resource) (spec null))
  res)

(defmethod parse-specification ((res resource) (spec cons))
  (iter (while spec)
	(for next-spec = (parse-next-specification res spec))
	(when (eq spec next-spec)
	  (error "Invalid specification : ~S" spec))
	(setq spec next-spec))
  res)


#+nil
(parse-specification *localhost*
                     '(:hostname "arrakis.lowh.net"))

(defmethod subclasses ((class class))
  (let (r)
    (labels ((walk (c)
	       (dolist (sub (sort (copy-seq
				   (closer-mop:class-direct-subclasses c))
				  #'string< :key #'class-name))
		 (pushnew sub r)
		 (walk sub))))
      (walk class))
    (nreverse r)))

(defun resource (type id &rest spec)
  (let ((r (or #1=(get-resource type id)
	       (setf #1# (make-resource type id)))))
    (when spec
      (parse-specification r spec))
    r))

(defmacro specify (&body specification)
  `(macrolet ,(mapcar (lambda (c)
			`(,(class-name c) (id &body s)
			   `(resource ',',(class-name c) ,id ,@s)))
		      (subclasses (find-class 'resource)))
     (parse-specification *localhost*
			  (list ,@specification))))

#+nil
(specify (user "billitch" :uid 19256 :group (group "billitch")))

;;  Methods for matching specified and probed values

(defgeneric match-specified-value (resource property specified probed))

(defmethod match-specified-value (resource property specified probed)
  (equalp specified (describe-probed-property-value resource property probed)))

(defmethod match-specified-value (resource (property (eql :ensure))
                                  (specified (eql :present))
                                  (probed null))
  t)

;;  Methods to get current status of resource

(defgeneric resource-diff (resource)
  (:documentation "Two values are returned :
First value lists properties out of specification in the following format :
  (PROPERTY-NAME SPECIFIED-VALUE PROBED-VALUE).
Second value lists properties in line with spec. Format is
  (PROPERTY-NAME VALUE)"))

(defmethod resource-diff ((res resource))
  (iter (for* (property specified) in (specified-properties res))
        (for probed = (get-probed res property))
        (for desc = (describe-probed-property-value res property probed))
        (if (match-specified-value res property specified desc)
            (collect `(,property ,specified) into ok)
            (collect `(,property ,specified ,desc) into diff))
        (finally (return diff))))

#+nil
(resource-diff (resource 'directory "/" :owner "root" :uid 0))

(defmethod resource-diff ((res resource-container))
  (append (call-next-method res)
          (sort (iter (for-resource r in res)
                      (for d = (resource-diff r))
                      (when d
                        (collect (cons r d))))
                #'resource-before-p
                :key #'first)))

(defmethod resource-diff ((host host))
  (with-host host
    (call-next-method)))

(defun resource-diff-to-plist (diff)
  (iter (for item in diff)
        (for key = (first item))
        (when (keywordp key)
          (collect key)
          (collect (second item)))))
