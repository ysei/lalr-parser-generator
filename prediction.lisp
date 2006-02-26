
(in-package :lalr-parser-generator)

;;;; FIRST and FOLLOW

(defun compute-prediction-sets (grammar)
  "Computes and returns the first, follow, and nullable sets for
GRAMMAR."
  (let ((nullable (make-hash-table))
	(follow (make-hash-table))
	(first (make-hash-table)))
    (flet ((nullable-p (x) (gethash x nullable)))
      (macrolet ((setf-union (dst src)
		   `(setf (gethash ,@dst) (union (gethash ,@dst)
					   (gethash ,@src)))))
	(do-for-each-terminal (z grammar)
	  (setf (gethash z first) (list z)))
	(do-until-unchanged (first follow nullable)
	  (do-for-each-production (x ys grammar)
	    (when (every #'nullable-p ys)
	      (setf (gethash x nullable) t))
	    (loop with k = (length ys)
		  for i below k
		  ;; Note - subseq 0 0 is NIL, the intended effect here.
		  when (every #'nullable-p (subseq ys 0 i))
		  do (setf-union (x first) ((nth i ys) first))
		  when (every #'nullable-p (subseq ys (1+ i) k))
		  do (setf-union ((nth i ys) follow) (x follow))
		  do (loop for j from (1+ i) to k
			   when (every #'nullable-p (subseq ys (1+ i) j))
			   do (setf-union ((nth i ys) follow)
					  ((nth j ys) first))))))
	(values first follow nullable)))))

;;; The following three functions are just for testing.  Combined,
;;; they perform the same functions as COMPUTE-PREDICTION-SETS

(defun list-nullable (grammar)
  (let ((nullable nil))
    (do-until-unchanged (nullable)
      (do-for-each-production (lhs rhs grammar)
	(when (or (null rhs)
		  (every #'(lambda (x) (member x nullable)) rhs))
	  (pushnew lhs nullable))))
    nullable))

(defun list-first-set (grammar nullable)
  (let ((first-set (make-hash-table)))
    (do-for-each-terminal (x grammar)
      (setf (gethash x first-set) (list x)))
    (do-until-unchanged (first-set)
      (do-for-each-production (lhs rhs grammar)
	(do ((r-> rhs (cdr r->))
	     (done-p nil))
	    ((or done-p (null r->)))
	  (when (not (member (car r->) nullable)) 
	    (setf (gethash lhs first-set)
		  (union (gethash lhs first-set)
			 (gethash (car r->) first-set)))
	    (setf done-p t))))

      (do-for-each-production (lhs rhs grammar)
	(do ((r-> rhs (cdr r->))
	     (done-p nil))
	    ((or done-p (null r->)))
	  (when (not (member (car r->) nullable)) 
	    (setf (gethash lhs first-set)
		  (union (gethash lhs first-set)
			 (gethash (car r->) first-set)))
	    (setf done-p t)))))
    first-set))

(defun list-follow-set (grammar nullable first-set)
  (let ((follow-set (make-hash-table)))
    (do-until-unchanged (follow-set)
      (do-for-each-production (lhs rhs grammar)
	(do ((r-> rhs (cdr r->))
	     (done-p nil))
	    ((or done-p (null r->)))
	  (when (every (lambda (x) (member x nullable)) (cdr r->))
	    (setf (gethash (car r->) follow-set)
		  (union (gethash (car r->) follow-set)
			 (gethash lhs follow-set))))

	  (loop for j from 1 to (length r->)
		do (progn
		     (when (every (lambda (x) (member x nullable))
				  (and (> j 1) (subseq r-> 1 (1- j))))
		       (setf (gethash (car r->) follow-set)
			     (union (gethash (car r->) follow-set)
				    (gethash (nth j r->) first-set)))))))))
    follow-set))

