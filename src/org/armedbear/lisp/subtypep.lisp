;;; subtypep.lisp
;;;
;;; Copyright (C) 2003-2004 Peter Graves
;;; $Id: subtypep.lisp,v 1.43 2004-02-02 20:53:26 piso Exp $
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

;;; Adapted from GCL.

(in-package "SYSTEM")

(defparameter *known-types* (make-hash-table))

(dolist (i '((ARITHMETIC-ERROR ERROR)
             (ARRAY)
             (BASE-STRING SIMPLE-STRING)
             (BIGNUM INTEGER)
             (BIT-VECTOR VECTOR)
             (BOOLEAN SYMBOL)
             (BUILT-IN-CLASS CLASS)
             (CELL-ERROR ERROR)
             (CHARACTER)
             (CLASS STANDARD-OBJECT)
             (COMPILED-FUNCTION FUNCTION)
             (COMPLEX NUMBER)
             (CONDITION)
             (CONS LIST)
             (CONTROL-ERROR ERROR)
             (DIVISION-BY-ZERO ARITHMETIC-ERROR)
             (END-OF-FILE STREAM-ERROR)
             (ERROR SERIOUS-CONDITION)
             (EXTENDED-CHAR CHARACTER NIL)
             (FILE-ERROR ERROR)
             (FIXNUM INTEGER)
             (FLOAT REAL)
             (FLOATING-POINT-INEXACT ARITHMETIC-ERROR)
             (FLOATING-POINT-INVALID-OPERATION ARITHMETIC-ERROR)
             (FLOATING-POINT-OVERFLOW ARITHMETIC-ERROR)
             (FLOATING-POINT-UNDERFLOW ARITHMETIC-ERROR)
             (FUNCTION)
             (GENERIC-FUNCTION FUNCTION)
             (HASH-TABLE)
             (INTEGER RATIONAL)
             (KEYWORD SYMBOL)
             (LIST SEQUENCE)
             (NULL BOOLEAN LIST)
             (NUMBER)
             (PACKAGE)
             (PACKAGE-ERROR ERROR)
             (PARSE-ERROR ERROR)
             (PATHNAME)
             (PRINT-NOT-READABLE ERROR)
             (PROGRAM-ERROR ERROR)
             (RANDOM-STATE)
             (RATIO RATIONAL)
             (RATIONAL REAL)
             (READER-ERROR PARSE-ERROR STREAM-ERROR)
             (READTABLE)
             (REAL NUMBER)
             (RESTART)
             (SERIOUS-CONDITION CONDITION)
             (SIMPLE-ARRAY ARRAY)
             (SIMPLE-BASE-STRING SIMPLE-STRING BASE-STRING)
             (SIMPLE-BIT-VECTOR BIT-VECTOR SIMPLE-ARRAY)
             (SIMPLE-CONDITION CONDITION)
             (SIMPLE-ERROR SIMPLE-CONDITION ERROR)
             (SIMPLE-STRING STRING SIMPLE-ARRAY)
             (SIMPLE-TYPE-ERROR SIMPLE-CONDITION TYPE-ERROR)
             (SIMPLE-VECTOR VECTOR SIMPLE-ARRAY)
             (SIMPLE-WARNING SIMPLE-CONDITION WARNING)
             (STANDARD-CHAR CHARACTER)
             (STANDARD-CLASS CLASS)
             (STANDARD-GENERIC-FUNCTION GENERIC-FUNCTION)
             (STANDARD-OBJECT)
             (STORAGE-CONDITION SERIOUS-CONDITION)
             (STREAM)
             (STREAM-ERROR ERROR)
             (STRING VECTOR)
             (STRUCTURE-CLASS CLASS STANDARD-OBJECT)
             (STYLE-WARNING WARNING)
             (SYMBOL)
             (TWO-WAY-STREAM STREAM)
             (TYPE-ERROR ERROR)
             (UNBOUND-SLOT CELL-ERROR)
             (UNBOUND-VARIABLE CELL-ERROR)
             (UNDEFINED-FUNCTION CELL-ERROR)
             (VECTOR ARRAY SEQUENCE)
             (WARNING CONDITION)))
  (setf (gethash (car i) *known-types*) (cdr i)))

(defun supertypes (type)
  (values (gethash type *known-types*)))

(defun known-type-p (type)
  (multiple-value-bind (value present-p) (gethash type *known-types*)
    present-p))

(defun sub-interval-p (i1 i2)
  (let (low1 high1 low2 high2)
    (if (null i1)
        (setq low1 '* high1 '*)
        (if (null (cdr i1))
            (setq low1 (car i1) high1 '*)
            (setq low1 (car i1) high1 (cadr i1))))
    (if (null i2)
        (setq low2 '* high2 '*)
        (if (null (cdr i2))
            (setq low2 (car i2) high2 '*)
            (setq low2 (car i2) high2 (cadr i2))))
    (when (and (consp low1) (integerp (car low1)))
      (setq low1 (1+ (car low1))))
    (when (and (consp low2) (integerp (car low2)))
      (setq low2 (1+ (car low2))))
    (when (and (consp high1) (integerp (car high1)))
      (setq high1 (1- (car high1))))
    (when (and (consp high2) (integerp (car high2)))
      (setq high2 (1- (car high2))))
    (cond ((eq low1 '*)
	   (unless (eq low2 '*)
	           (return-from sub-interval-p nil)))
          ((eq low2 '*))
	  ((consp low1)
	   (if (consp low2)
	       (when (< (car low1) (car low2))
		     (return-from sub-interval-p nil))
	       (when (< (car low1) low2)
		     (return-from sub-interval-p nil))))
	  ((if (consp low2)
	       (when (<= low1 (car low2))
		     (return-from sub-interval-p nil))
	       (when (< low1 low2)
		     (return-from sub-interval-p nil)))))
    (cond ((eq high1 '*)
	   (unless (eq high2 '*)
	           (return-from sub-interval-p nil)))
          ((eq high2 '*))
	  ((consp high1)
	   (if (consp high2)
	       (when (> (car high1) (car high2))
		     (return-from sub-interval-p nil))
	       (when (> (car high1) high2)
		     (return-from sub-interval-p nil))))
	  ((if (consp high2)
	       (when (>= high1 (car high2))
		     (return-from sub-interval-p nil))
	       (when (> high1 high2)
		     (return-from sub-interval-p nil)))))
    (return-from sub-interval-p t)))

(defun dimension-subtypep (dim1 dim2)
  (cond ((eq dim2 '*)
         t)
        ((equal dim1 dim2)
         t)
        ((integerp dim2)
         (and (consp dim1) (= (length dim1) dim2)))
        ((eql dim1 0)
         (null dim2))
        ((integerp dim1)
         (and (consp dim2)
              (= (length dim2) dim1)
              (equal dim2 (make-list dim1 :initial-element '*))))
        ((and (consp dim1) (consp dim2) (= (length dim1) (length dim2)))
         (do* ((list1 dim1 (cdr list1))
               (list2 dim2 (cdr list2))
               (e1 (car list1) (car list1))
               (e2 (car list2) (car list2)))
              ((null list1) t)
           (unless (or (eq e2 '*) (eql e1 e2))
              (return nil))))
        (t
         nil)))

(defun simple-subtypep (type1 type2)
  (multiple-value-bind (type1-supertypes type1-known-p) (gethash type1 *known-types*)
    (if type1-known-p
        (if (memq type2 type1-supertypes)
            t
            (dolist (supertype type1-supertypes)
              (when (simple-subtypep supertype type2)
                (return t))))
        nil)))

(defun subtypep (type1 type2)
  (when (or (eq type1 type2)
            (null type1)
            (eq type2 t)
            (eq type2 #.(find-class t)))
    (return-from subtypep (values t t)))
  (when (and (atom type1) (atom type2))
    (let* ((classp-1 (classp type1))
           (classp-2 (classp type2))
           class1 class2)
      (when (and (setf class1 (if classp-1
                                  type1
                                  (and (symbolp type1) (find-class type1 nil))))
                 (setf class2 (if classp-2
                                  type2
                                  (and (symbolp type2) (find-class type2 nil)))))
        (return-from subtypep
                     (if (member class2 (class-precedence-list class1))
                         (values t t)
                         (values nil t))))
      (when (or classp-1 classp-2)
        (let ((t1 (if classp-1 (class-name type1) type1))
              (t2 (if classp-2 (class-name type2) type2)))
          (return-from subtypep (values (simple-subtypep t1 t2) t))))))
  (setf type1 (normalize-type type1)
        type2 (normalize-type type2))
  (when (eq type1 type2)
    (return-from subtypep (values t t)))
  (let (t1 t2 i1 i2)
    (if (atom type1)
        (setq t1 type1 i1 nil)
        (setq t1 (car type1) i1 (cdr type1)))
    (if (atom type2)
        (setq t2 type2 i2 nil)
        (setq t2 (car type2) i2 (cdr type2)))
    (cond ((eq t1 'atom)
           (return-from subtypep (values (eq t2 t) t)))
          ((eq t2 'atom)
           (return-from subtypep (cond ((memq t1 '(cons list sequence))
                                        (values nil t))
                                       (t
                                        (values t t)))))
          ((eq t1 'member)
           (dolist (e i1)
             (unless (typep e type2) (return-from subtypep (values nil t))))
           (return-from subtypep (values t t)))
          ((eq t1 'eql)
           (case t2
             (EQL
              (return-from subtypep (values (eql (car i1) (car i2)) t)))
             (SATISFIES
              (return-from subtypep (values (funcall (car i2) (car i1)) t)))
             (t
              (return-from subtypep (values (typep (car i1) type2) t)))))
          ((eq t1 'or)
           (dolist (tt i1)
             (multiple-value-bind (tv flag) (subtypep tt type2)
               (unless tv (return-from subtypep (values tv flag)))))
           (return-from subtypep (values t t)))
          ((eq t1 'and)
           (dolist (tt i1)
             (let ((tv (subtypep tt type2)))
               (when tv (return-from subtypep (values t t)))))
           (return-from subtypep (values nil nil)))
          ((eq t1 'cons)
           (case t2
             ((LIST SEQUENCE)
              (return-from subtypep (values t t)))
             (CONS
              (when (and (subtypep (car i1) (car i2))
                         (subtypep (cadr i1) (cadr i2)))
                (return-from subtypep (values t t)))))
           (return-from subtypep (values nil (known-type-p t2))))
          ((eq t2 'or)
           (dolist (tt i2)
             (let ((tv (subtypep type1 tt)))
               (when tv (return-from subtypep (values t t)))))
           (return-from subtypep (values nil nil)))
          ((eq t2 'and)
           (dolist (tt i2)
             (multiple-value-bind (tv flag) (subtypep type1 tt)
               (unless tv (return-from subtypep (values tv flag)))))
           (return-from subtypep (values t t)))
          ((null (or i1 i2))
           (return-from subtypep (values (simple-subtypep t1 t2) t)))
          ((classp t2)
           (cond ((eq t2 (find-class t1 nil))
                  (values t t))
                 ((and (eq t2 #.(find-class 'array))
                       (memq t1 '(array simple-array vector simple-vector string
                                  simple-string simple-base-string bit-vector
                                  simple-bit-vector)))
                  (values t t))
                 ((eq t2 #.(find-class 'vector))
                  (cond ((memq t1 '(string simple-string))
                         (values t t))
                        ((eq t1 'array)
                         (let ((dim (cadr i1)))
                           (if (or (eql dim 1)
                                   (and (consp dim) (= (length dim) 1)))
                               (values t t)
                               (values nil t))))
                        (t
                         (values nil t))))
                 ((and (eq t2 #.(find-class 'bit-vector))
                       (eq t1 'simple-bit-vector))
                  (values t t))
                 (t
                  (values nil nil))))
          ((eq t2 'sequence)
           (cond ((memq t1 '(null cons list))
                  (values t t))
                 ((memq t1 '(array simple-array))
                  (if (and (cdr i1) (consp (cadr i1)) (null (cdadr i1)))
                      (values t t)
                      (values nil t)))
                 (t (values nil (known-type-p t1)))))
          ((eq t1 'float)
           (if (memq t2 '(float real number))
               (values (sub-interval-p i1 i2) t)
               (values nil (known-type-p t2))))
          ((eq t1 'integer)
           (cond ((memq t2 '(integer rational real number))
                  (values (sub-interval-p i1 i2) t))
                 ((eq t2 'bignum)
                  (values
                   (or (sub-interval-p i1 (list '* (list most-negative-fixnum)))
                       (sub-interval-p i1 (list (list most-positive-fixnum) '*)))
                   t))
                 (t
                   (values nil (known-type-p t2)))))
          ((eq t1 'rational)
           (if (memq t2 '(rational real number))
               (values (sub-interval-p i1 i2) t)
               (values nil (known-type-p t2))))
          ((eq t1 'real)
           (if (memq t2 '(real number))
               (values (sub-interval-p i1 i2) t)
               (values nil (known-type-p t2))))
          ((and (eq t1 #.(find-class 'array)) (eq t2 'array))
           (cond ((equal i2 '(* *))
                  (values t t))
                 (t
                  (values nil t))))
          ((and (memq t1 '(array simple-array)) (eq t2 'array))
           (let ((e1 (car i1))
                 (e2 (car i2))
                 (d1 (cadr i1))
                 (d2 (cadr i2)))
             (cond ((and (eq e2 '*) (eq d2 '*))
                    (values t t))
                   ((or (eq e2 '*)
                        (equal e1 e2)
                        (equal (upgraded-array-element-type e1)
                               (upgraded-array-element-type e2)))
                    (values (dimension-subtypep d1 d2) t))
                   (t
                    (values nil t)))))
          ((and (memq t1 '(array simple-array)) (eq t2 'string))
           (let ((element-type (car i1))
                 (dim (cadr i1))
                 (size (car i2)))
             (unless (subtypep element-type 'character)
               (return-from subtypep (values nil t)))
             (when (integerp size)
               (if (and (consp dim) (= (length dim) 1) (eql (car dim) size))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))
             (when (or (null size) (eql size '*))
               (if (or (eql dim 1)
                       (and (consp dim) (= (length dim) 1)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))))
          ((and (eq t1 'simple-array) (eq t2 'simple-string))
           (let ((element-type (car i1))
                 (dim (cadr i1))
                 (size (car i2)))
             (unless (subtypep element-type 'character)
               (return-from subtypep (values nil t)))
             (when (integerp size)
               (if (and (consp dim) (= (length dim) 1) (eql (car dim) size))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))
             (when (or (null size) (eql size '*))
               (if (or (eql dim 1)
                       (and (consp dim) (= (length dim) 1)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))))
          ((and (memq t1 '(string simple-string)) (eq t2 'array))
           (let ((element-type (car i2))
                 (dim (cadr i2))
                 (size (car i1)))
             (unless (eq element-type '*)
               (return-from subtypep (values nil t)))
             (when (integerp size)
               (if (or (eq dim '*)
                       (and (consp dim) (= (length dim) 1) (eql (car dim) size)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))
             (when (or (null size) (eql size '*))
               (if (or (eq dim '*)
                       (eql dim 1)
                       (and (consp dim) (= (length dim) 1)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))))
          ((and (eq t1 'simple-array) (eq t2 'simple-array))
           (let ((e1 (car i1))
                 (e2 (car i2))
                 (d1 (cadr i1))
                 (d2 (cadr i2)))
             (cond ((and (eq e2 '*) (eq d2 '*))
                    (values t t))
                   ((or (eq e2 '*)
                        (equal e1 e2)
                        (equal (upgraded-array-element-type e1)
                               (upgraded-array-element-type e2)))
                    (values (dimension-subtypep d1 d2) t))
                   (t
                    (values nil t)))))
          ((and (eq t1 'simple-string) (eq t2 'simple-array))
           (let ((element-type (car i2))
                 (dim (cadr i2))
                 (size (car i1)))
             (unless (eq element-type '*)
               (return-from subtypep (values nil t)))
             (when (integerp size)
               (if (or (eq dim '*)
                       (and (consp dim) (= (length dim) 1) (eql (car dim) size)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))
             (when (or (null size) (eql size '*))
               (if (or (eq dim '*)
                       (eql dim 1)
                       (and (consp dim) (= (length dim) 1)))
                   (return-from subtypep (values t t))
                   (return-from subtypep (values nil t))))))
          ((eq t2 'simple-array)
           (values nil t))
          (t
           (values nil nil)))))

(when (and (fboundp 'jvm::jvmcompile) (not (autoloadp 'jvm::jvm-compile)))
  (mapcar #'jvm::jvm-compile '(normalize-type
                               sub-interval-p
                               simple-subtypep
                               subtypep)))
