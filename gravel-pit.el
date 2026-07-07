;;; gravel-pit.el ---  sandboxed elisp interprete -*- lexical-binding: t -*-

;; Author: Elijah Charles
;; Version: 0.0.1
;; Package-Requires: ((emacs "29.1"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;;;; Commentary:

;; Proof of concept using macroexpand-all and side-effect-free as the basis of a sandboxed elisp interpreter.

(defvar-local gravel-pit--primitives nil
  "Allowed host operations.")

(defvar-local gravel-pit--functions nil
  "Guest functions.")

(defun gravel-pit--apply-closure (closure arguments)
  "Execute a CLOSURE with ARGUMENTS."
  (let ((new-env (cadddr closure))
        (params (cadr closure))
        (result nil))
    (while params
      (setq new-env (cons (cons (car params) (car arguments)) new-env)
            params (cdr params)
            arguments (cdr arguments)))
    (dolist (form (caddr closure) result)
      (setq result (gravel-pit--eval form new-env)))))

(defun gravel-pit--eval (expression environment)
  "Eval EXPRESSION in ENVIRONMENT."
  (cond
   ((or (numberp expression) (stringp expression) (memq expression '(t nil)))
    expression)

   ((symbolp expression)
    (let ((binding (assoc expression environment)))
      (if binding
          (cdr binding)
        (error "Unbound variable: %s" expression))))

   ((consp expression)
    (let ((operator (car expression))
          (arguments (cdr expression)))
      (cond
       ((eq operator 'quote)
        (car arguments))

       ((memq operator '(lambda function))
        (if (eq operator 'function)
            (gravel-pit--eval (car arguments) environment)
          (list 'closure (car arguments) (cdr arguments) environment)))

       ((eq operator 'progn)
        (let ((result nil))
          (dolist (form arguments result)
            (setq result (gravel-pit--eval form environment)))))

       ((eq operator 'if)
        (if (gravel-pit--eval (car arguments) environment)
            (gravel-pit--eval (cadr arguments) environment)
          (gravel-pit--eval (caddr arguments) environment)))

       ((eq operator 'setq)
        (let ((args arguments)
              (val nil))
          (while args
            (let* ((var (car args))
                   (binding (assoc var environment)))
              (setq val (gravel-pit--eval (cadr args) environment))
              (if binding
                  (setcdr binding val)
                (error "Cannot setq unbound variable: %s" var)))
            (setq args (cddr args)))
          val))

       ((eq operator 'while)
        (let ((condition (car arguments))
              (body (cdr arguments)))
          (while (gravel-pit--eval condition environment)
            (dolist (form body)
              (gravel-pit--eval form environment)))
          nil))

       ((memq operator '(let let*))
        (let ((new-env environment)
              (result nil))
          (dolist (binding (car arguments))
            (let ((var (if (consp binding) (car binding) binding))
                  (val (if (consp binding) 
                           (gravel-pit--eval (cadr binding)
                                             (if (eq operator 'let*) new-env environment)) 
                         nil)))
              (setq new-env (cons (cons var val) new-env))))
          (dolist (form (cdr arguments) result)
            (setq result (gravel-pit--eval form new-env)))))

       ;; allow inline funcs
       ((eq operator 'defalias)
        (let ((func-name (gravel-pit--eval (car arguments) environment))
              (func-body (gravel-pit--eval (cadr arguments) environment)))
          (puthash func-name func-body gravel-pit--functions)
          func-name))

       ((eq operator 'funcall)
        (let ((func (gravel-pit--eval (car arguments) environment))
              (eval-args (mapcar (lambda (arg) (gravel-pit--eval arg environment))
                                 (cdr arguments))))
          (cond
           ((and (consp func) (eq (car func) 'closure))
            (gravel-pit--apply-closure func eval-args))
           ((symbolp func)
            (cond
             ((gethash func gravel-pit--primitives)
              (apply (gethash func gravel-pit--primitives) eval-args))
             ((gethash func gravel-pit--functions)
              (gravel-pit--apply-closure (gethash func gravel-pit--functions) eval-args))
             (t (error "Void function: %s" func))))
           (t (error "Invalid funcall target: %s" func)))))

       (t
        (let ((eval-args (mapcar (lambda (arg) (gravel-pit--eval arg environment))
                                 arguments)))
          (cond
           ((and (symbolp operator) (gethash operator gravel-pit--primitives))
            (apply (gethash operator gravel-pit--primitives) eval-args))
           
           ((and (symbolp operator) (gethash operator gravel-pit--functions))
            (gravel-pit--apply-closure (gethash operator gravel-pit--functions) eval-args))
           
           ((consp operator)
            (let ((func (gravel-pit--eval operator environment)))
              (if (and (consp func) (eq (car func) 'closure))
                  (gravel-pit--apply-closure func eval-args)
                (error "Invalid operator evaluation: %s" operator))))
           
           (t (error "Void function: %s" operator))))))))))

(defun gravel-pit-run (expression extra-operations)
  "Expand EXPRESSION and execute."
  (let ((expanded-expression (macroexpand-all expression))
        (gravel-pit--primitives (make-hash-table :test 'eq))
        (gravel-pit--functions (make-hash-table :test 'eq)))

    (mapatoms
     (lambda (sym)
       (when (and (fboundp sym) (get sym 'side-effect-free))
         (puthash sym sym gravel-pit--primitives))))

    (dolist (op extra-operations)
      (puthash op op gravel-pit--primitives))

    (gravel-pit--eval expanded-expression nil)))
