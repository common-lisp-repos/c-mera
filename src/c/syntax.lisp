(in-package :cm-c)

(defmacro c-syntax (tags lambda-list &body body)
  `(defsyntax ,tags (:cmu-c) ,lambda-list ,@body))

(defmacro make-expressions (list)
  ;; make expression statements with semicolon and wrap in quoties
  `(make-nodelist ,list :prepend (expression-statement t) :quoty t))

(defmacro make-block (list)
  "Code block with curly braces and intendation"
  `(compound-statement
    ;; curly braces: t
    t
    ;(make-nodelist ,list)))
    ;; make expressions with ';' delimiter
    (make-expressions ,list)))

(defmacro make-simple-block (list)
  "Code block without underlying nodelist.
   Used for 'bodys' where implicit progn is required"
  `(compound-statement
    ;; curly braces: t
    t
    ;; also handle expressions when 'progn' is absent
    (expression-statement t (quoty ,list))))

(c-syntax block (&body body)
  "Code block with curly braces and intendation"
  `(make-block ,body))

(c-syntax progn (&body body)
  "Code block without curly craces nor intendation"
  ;; make expressions with ';' delimiter
  `(make-expressions ,body))

(c-syntax set (&rest rest)
  "Assigment operator for multiple inputs"
  (when (oddp (length rest))
    (error "Set operator with odd number of elements: ~a" rest))
  (if (eql (length rest) 2)
      ;; signel assignment
      `(assignment-expression '= (make-node ,(pop rest)) (make-node ,(pop rest)))
      ;; muliple assignments
      `(make-expressions
	;; collect item  pairwise and emmit sigle assignments
	,(loop while rest collect
	    `(assignment-expression '= (make-node ,(pop rest)) (make-node ,(pop rest)))))))

(c-syntax (= *= /= %= += -= <<= >>= &= ^= \|=) (variable value)
  "Assignment operators for single inputs"
  `(assignment-expression ',tag (make-node ,variable) (make-node ,value)))

(c-syntax (/ > < == != >= <= \| \|\| % << >> or and ^ &&) (&rest rest)
  "Infix expressions for multiple inputs"
  `(infix-expression ',tag (make-nodelist ,rest)))

(c-syntax (- + * &) (&rest rest)
  "Infix or prefix version"
  (if (eql (length rest) 1)
      `(prefix-expression ',tag (make-node ,@rest))
      `(infix-expression  ',tag (make-nodelist ,rest))))

(c-syntax (~ !) (item)
  "Prefix operators"
  `(prefix-expression ',tag (make-node ,item)))

(c-syntax (addr-of) (item)
  "Address-of function (&)"
  `(prefix-expression '& (make-node ,item)))

(c-syntax (targ-of dref) (item)
  "Taget-of or dereferencing pointer"
  `(prefix-expression '* (make-node ,item)))

(c-syntax prefix++ (item)
  "Prefix operator ++"
  `(prefix-expression '++ (make-node ,item)))

(c-syntax prefix-- (item)
  "Prefix operator --"
  `(prefix-expression '-- (make-node ,item)))

(c-syntax postfix-- (item)
  "Postfix operator --"
  `(postfix-expression '-- (make-node ,item)))

(c-syntax postfix++ (item)
  "Postfix operator ++"
  `(postfix-expression '++ (make-node ,item)))

(c-syntax postfix* (item)
  "Postfix operator *"
  `(postfix-expression '* (make-node ,item)))

(c-syntax struct (name &body body)
  "Struct definition"
  `(struct-definition
    ;; struct name
    (make-node ,name)
    ;; struct body
    (compound-statement
     ;; curly braces: t
     t
     ;; build subnodes
     (make-nodelist ,body))))

(c-syntax union (name &body body)
  "Syntax for union"
  `(union-definition
    ;; union name
    (make-node ,name)
    ;; union body
    (compound-statement
     ;; curly braces: t
     t
     ;; build subnodes
     (make-nodelist ,body))))

(c-syntax enum (&rest rest)
  "Syntax for enum"
  (destructuring-bind (enum-list &optional name) (reverse rest)
    (setf enum-list (mapcar #'(lambda (x)
				(if (listp x)
				    x
				    (list x))) enum-list))
    `(enum-definition
      ;; enum name
      ,(when name
	 `(make-node ,name))
      ;; enums as parameter list
      (make-nodelist ,enum-list :prepend decompose-enum))))

(c-syntax (aref array) (array &rest indizes)
  "Array reference"
  (if (not indizes) 
	(setf indizes '(nil)))
  `(array-reference (make-node ,array) (make-nodelist ,indizes)))

(c-syntax oref (object component)
  "Object reference"
  `(object-reference (make-node ,object) (make-node ,component)))

(c-syntax pref (pointer component)
  "Pointer reference"
  `(pointer-reference (make-node ,pointer) (make-node ,component)))

(c-syntax type (type)
  "C data type"
  `(type (make-node ,type)))

(c-syntax specifier (specifier)
  "Type specifier/qualifier"
  `(specifier (make-node ,specifier)))

(c-syntax include (file)
  "Include for c files"
   `(include (quoty ,file)))

(c-syntax comment (comment &key (prefix nil) (noprefix nil))
  "Comment with default ('//') or user defined delimiter."
  `(comment
    (quoty ,(if prefix prefix "//"))
    (quoty ,comment)))
    ;(make-node ,(if prefix `,prefix '\/\/))
    ;(make-node ,comment)))

(defmacro decompose-declaration (item)
  "Decompose declaration item"
  ;; check if initialization is present
  (if (let ((symbol (first (last (butlast item)))))
	(and (symbolp symbol)
	     (equal (symbol-name symbol) "=")))


      ;; decompose arg list with init
      (let ((specifier (butlast item 4))
	    (type+id+val (last item 4)))
	(let ((type (first type+id+val))
	      (id   (second type+id+val))
	      (init (fourth type+id+val)))
	  ;; make declaration node
	  `(declaration-item
	    ;; set specifiers
	    ,(when specifier
	       `(specifier
		 (make-nodelist ,specifier)))
	    ;; set type
	    (type (make-node ,type))
	    ;; set identifier
	    (make-node ,id)
	    ;; set value
	    (declaration-value
	      (make-node ,init)))))
      
      ;; decompose arg list without init
      (let ((specifier (butlast item 2))
	    (type+id (last item 2)))
	(let ((type (first type+id))
	      (id   (second type+id)))
	  ;; make declaration node
	  `(declaration-item
	    ;; set specifiers
	    ,(when specifier
	       `(specifier
		 (make-nodelist ,specifier)))
	    ;; set type
	    (type (make-node ,type))
	    ;; set identifier
	    ,(when id
	       `(make-node ,id))
	    ;; no initialization present
	    nil)))))

(defmacro decompose-type (item)
  "Decompose type like declaration but without name"
  `(decompose-declaration (,@item nil)))

(defmacro decompose-enum (item)
  "Decompose enum like declaration but without type"
  `(declaration-item
    ;; no specifier
    nil
    ;; no type
    nil
    ;; enum name
    (make-node ,(first item))
    ;; enum init
    ,(when (second item)
	   `(declaration-value
		 (make-node ,(second item))))))

(c-syntax decl (bindings &body body)
  "Declare variables"
  `(declaration-list
    ;; braces t, adjusted later by traverser
    t
    ;; make single declarations/bindings
    (make-nodelist
     ,bindings :prepend decompose-declaration)
    ;; make listnode with body
    ,(when body
	 ;; make single expression statements
	 `(make-expressions ,body))))

(c-syntax function (name parameters -> type &body body &environment env)
  "Define c function"
  (declare (ignore ->))
  `(function-definition
    ;; function name + type
    ,(if (listp type)
	 ;; check if macro/function or list
	 (let ((first (first type)))
	   (if (and (not (listp first)) (fboundp! first env))
	       ;; type is macro or function
	       `(decompose-declaration (,type ,name))
	       ;; type is list with type information
	       `(decompose-declaration (,@type ,name))))
	 ;; type is single symbol
	 `(decompose-declaration (,type ,name)))
    ;; parameter list
    (parameter-list
     (make-nodelist ,parameters :prepend decompose-declaration))
    ;; body
    ,(when body
       `(make-block ,body))))

(c-syntax fpointer (name &optional parameters)
  "Define a function pointer"
  `(function-pointer
    ;; function pointer identifier
    (make-node ,name)
    ;; function pointer parameters
    (parameter-list
     (make-nodelist ,parameters :prepend decompose-declaration))))

(c-syntax for (init &body body)
  "The c for loop"
  `(for-statement
    ;; check if initialization present
    ,(when (first init)
	 ;; set init
	 `(decompose-declaration ,(first init)))
    ;; test 
    (make-node ,(second init))
    ;; step
    (make-node ,(third init))
    ;; the loop body
    (make-block ,body)))
    ;(make-expressions ,body)))

(c-syntax if (test if-body &optional else-body)
  "The c if expression"
  `(if-statement
    ;; case test
    (make-node ,test)
    ;; if true:
    (make-simple-block ,if-body)
    ;; if else and present
    ,(when else-body
       `(make-simple-block ,else-body))))

(c-syntax ? (test then else)
  "The conditinal expression 'test ? then : else'"
  `(conditional-expression
    (make-node ,test)
    (make-node ,then)
    (make-node ,else)))

(c-syntax while (test &body body)
  "The c while loop"
  `(while-statement
    ;; while clause
    (make-node ,test)
    ;; body expressions
    (make-block ,body)))

(c-syntax typedef (&rest rest)
  "Typedef for c types"
  `(typedef
    ;; decompose type + alias
    (decompose-declaration ,rest)))

(c-syntax cast (&rest rest)
  "Cast type"
  `(cast-expression
    ;; cast to type, with nil variable
    (decompose-type ,(butlast rest))
    ;; casted object
    (make-node ,(first (last rest)))))
     
(c-syntax sizeof (&rest type)
  "C sizeof function"
  `(function-call
    ;; function name
    (make-node sizeof)
    ;; rest ('type') as single argmument
    (decompose-type ,type)))

(c-syntax float-type (item)
  "Generate 'f' suffixes"
  `(float-type (make-node ,item)))

(c-syntax (goto continue break return) (&optional item)
  "Jump statements with optional item"
  `(jump-statement
    (make-node ,tag)
    ,(when item `(make-node ,item))))

(c-syntax not (item)
  "Not-expression"
  `(not-expression (make-node ,item)))

(c-syntax clist (&rest rest)
  "C style list"
  `(clist (make-nodelist ,rest)))

(c-syntax funcall (function &rest args)
  "C function call"
  `(function-call
    (make-node ,function)
    (make-nodelist ,args)))

;; build 'lisp' and 'cm' macros in :cmu-c package
;; lisp -> switch inside scope to lisp functions
;; cm   -> switch isnide scope to c-mera
;;         (might be useful inside lisp scope)
;; c-symbols: defined in c-mera.asd
(build-context-switches
 :user-package :cmu-c
 :symbols c-symbols)

(build-swap-package
 :user-package :cmu-c
 :swap-package :cms-c
 :symbols c-swap)


;;TODO
;; - peprocessor macro
;; - source pos
;; - do-while

	  
