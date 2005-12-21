;;; compiler-types.lisp
;;;
;;; Copyright (C) 2005 Peter Graves
;;; $Id: compiler-types.lisp,v 1.20 2005-12-21 03:14:16 piso Exp $
;;;
;;; This program is free software; you can redistribute it and/or
;;; modify it under the terms of the GNU General Public License
;;; as published by the Free Software Foundation; either version 2
;;; of the License, or (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

;;; Type information that matters to the compiler.

(in-package #:system)

(export '(integer-type-low
          integer-type-high
          integer-type-p
          %make-integer-type
          make-integer-type
          +fixnum-type+
          +integer-type+
          fixnum-type-p
          fixnum-constant-value
          integer-constant-value
          java-long-type-p
          make-compiler-type
          compiler-subtypep
          function-result-type
          defknown))

(defstruct (integer-type (:constructor %make-integer-type (low high)))
  low
  high)

(defconstant +fixnum-type+  (%make-integer-type most-negative-fixnum
                                                most-positive-fixnum))
(defconstant +integer-type+ (%make-integer-type nil nil))

(declaim (ftype (function (t) t) make-integer-type))
(defun make-integer-type (type)
  (if (integer-type-p type)
      type
      (cond ((eq type 'FIXNUM)
             +fixnum-type+)
            ((eq type 'INTEGER)
             +integer-type+)
            (t
             (setf type (normalize-type type))
             (when (and (consp type) (eq (%car type) 'INTEGER))
               (let ((low (second type))
                     (high (third type)))
                 (if (eq low '*)
                     (setf low nil)
                     (when (and (consp low) (integerp (%car low)))
                       (setf low (1+ (%car low)))))
                 (if (eq high '*)
                     (setf high nil)
                     (when (and (consp high) (integerp (%car high)))
                       (setf high (1- (%car high)))))
                 (%make-integer-type low high)))))))

(declaim (ftype (function (t) t) fixnum-type-p))
(defun fixnum-type-p (compiler-type)
  (and (integer-type-p compiler-type)
       (fixnump (integer-type-low compiler-type))
       (fixnump (integer-type-high compiler-type))))

(declaim (ftype (function (t) t) fixnum-constant-value))
(defun fixnum-constant-value (compiler-type)
  (when (and compiler-type (integer-type-p compiler-type))
    (let ((low (integer-type-low compiler-type))
          high)
      (when (fixnump low)
        (setf high (integer-type-high compiler-type))
        (when (and (fixnump high) (= high low))
          high)))))

(declaim (ftype (function (t) t) integer-constant-value))
(defun integer-constant-value (compiler-type)
  (when (and compiler-type (integer-type-p compiler-type))
    (let ((low (integer-type-low compiler-type))
          high)
      (when (integerp low)
        (setf high (integer-type-high compiler-type))
        (when (and (integerp high) (= high low))
          high)))))

(declaim (ftype (function (t) t) java-long-type-p))
(defun java-long-type-p (compiler-type)
  (and (integer-type-p compiler-type)
       (typep (integer-type-low compiler-type)
              (list 'INTEGER most-negative-java-long most-positive-java-long))
       (typep (integer-type-high compiler-type)
              (list 'INTEGER most-negative-java-long most-positive-java-long))))


(declaim (ftype (function (t t) t) make-union-type))
(defun make-union-type (type1 type2)
  (cond ((and (integer-type-p type1)
              (integer-type-p type2))
         (let ((low1 (integer-type-low type1))
               (low2 (integer-type-low type2))
               (high1 (integer-type-high type1))
               (high2 (integer-type-high type2)))
           (if (and low1 low2 high1 high2)
               (%make-integer-type (min low1 low2) (max high1 high2))
               +integer-type+)))
        (t
         t)))

(declaim (ftype (function (t) t) make-compiler-type))
(defun make-compiler-type (typespec)
  (if (integer-type-p typespec)
      typespec
      (let ((type (normalize-type typespec)))
        (cond ((consp type)
               (let ((car (%car type)))
                 (cond ((eq car 'INTEGER)
                        (make-integer-type type))
                       ((eq car 'SIMPLE-STRING)
                        'SIMPLE-STRING)
                       ((eq car 'STRING)
                        'STRING)
                       ((eq car 'OR)
                        (case (length (cdr type))
                          (1
                           (make-compiler-type (second type)))
                          (2
                           (make-union-type (make-compiler-type (second type))
                                            (make-compiler-type (third type))))
                          (t
                           t)))
                       ((subtypep type 'FIXNUM)
                        +fixnum-type+)
                       (t
                        t))))
              ((memq type '(BOOLEAN CHARACTER HASH-TABLE STREAM SYMBOL))
               type)
              (t
               t)))))

(defun integer-type-subtypep (type1 typespec)
  (if (eq typespec 'INTEGER)
      t
      (let ((type2 (make-integer-type typespec)))
        (when type2
          (let ((low1 (integer-type-low type1))
                (high1 (integer-type-high type1))
                (low2 (integer-type-low type2))
                (high2 (integer-type-high type2)))
            (cond ((and low1 low2 high1 high2)
                   (and (>= low1 low2) (<= high1 high2)))
                  ((and low1 low2 (< low1 low2))
                   nil)
                  ((and high1 high2) (> high1 high2)
                   nil)
                  ((and (null low1) low2)
                   nil)
                  ((and (null high1) high2)
                   nil)
                  (t
                   t)))))))

(defun compiler-subtypep (compiler-type typespec)
  (cond ((eq typespec t)
         t)
        ((eq compiler-type typespec)
         t)
        ((eq typespec 'STRING)
         (memq compiler-type '(STRING SIMPLE-STRING)))
        ((integer-type-p compiler-type)
         (integer-type-subtypep compiler-type typespec))))

(defvar *function-result-types* (make-hash-table :test 'equal))

(defun function-result-type (name)
  (gethash1 name (the hash-table *function-result-types*)))

(defun set-function-result-type (name result-type)
  (setf (gethash name (the hash-table *function-result-types*)) result-type))

(defun %defknown (name-or-names argument-types result-type)
  (declare (ignore argument-types))
  (let ((type (make-compiler-type result-type)))
    (if (or (symbolp name-or-names) (setf-function-name-p name-or-names))
        (set-function-result-type name-or-names type)
        (dolist (name name-or-names)
          (set-function-result-type name type))))
  name-or-names)

(defmacro defknown (name-or-names argument-types result-type)
  `(eval-when (:compile-toplevel :load-toplevel :execute)
     (%defknown ',name-or-names ',argument-types ',result-type)))

(provide '#:compiler-types)
