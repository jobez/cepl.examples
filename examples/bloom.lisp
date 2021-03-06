(in-package :cepl.examples)

;; NOTE: Ensure you have loaded cepl-image-helper (or cepl-default)

(defparameter cols nil)
(defparameter cols-sampler nil)

(defparameter *loop* 0)
(defparameter *quad*
  (make-gpu-array
   (list (list (v! -1.0   1.0 0 0) (v!  0.0   1.0))
	 (list (v! -1.0  -1.0 0 0) (v!  0.0   0.0))
	 (list (v!  1.0  -1.0 0 0) (v!  1.0   0.0))
	 (list (v! -1.0   1.0 0 0) (v!  0.0   1.0))
	 (list (v!  1.0  -1.0 0 0) (v!  1.0   0.0))
	 (list (v!  1.0   1.0 0 0) (v!  1.0   1.0)))
   :element-type 'g-pt
   :dimensions 6))
(defparameter *quad-stream*
  (make-buffer-stream *quad* :retain-arrays t))

(defun-g passthrough-vert ((quad g-pt))
  (values (v! (pos quad) 1) (tex quad)))

;;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(defun-g passthrough-frag ((tc :vec2) &uniform (tex :sampler-2d))
  (texture tex tc))

(def-g-> blit ()
  #'passthrough-vert #'passthrough-frag)

;;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(defun-g qkern ((tc :vec2) &uniform (tex :sampler-2d) (offset :vec2))
  (+ (* (texture tex (- tc offset)) 0.3125)
     (* (texture tex tc) 0.375)
     (* (texture tex (+ tc offset)) 0.3125)))

(def-g-> smooth ()
  #'passthrough-vert #'qkern)

;;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(defun-g fourtex ((tc :vec2) &uniform (t0 :sampler-2d) (t1 :sampler-2d)
                  (t2 :sampler-2d) (t3 :sampler-2d) (scale-effect :float))
  (let ((tc (* tc (v! 1 -1))))
    (+ (* (texture t0 tc) 1)
       (* (texture t1 tc) scale-effect)
       (* (texture t2 tc) scale-effect)
       (* (texture t3 tc) scale-effect))))

(def-g-> combine ()
  #'passthrough-vert #'fourtex)

;;- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

(defvar* fbos
  (c0 (make-fbo '(0 :dimensions (512 512))))
  (sc0 (sample (attachment-tex c0 0)))
  (c1 (make-fbo '(0 :dimensions (256 256))))
  (sc1 (sample (attachment-tex c1 0)))
  (c2 (make-fbo '(0 :dimensions (128 128))))
  (sc2 (sample (attachment-tex c2 0)))
  (c3 (make-fbo '(0 :dimensions (64 64))))
  (sc3 (sample (attachment-tex c3 0)))
  (h0 (make-fbo '(0 :dimensions (512 512))))
  (sh0 (sample (attachment-tex h0 0)))
  (h1 (make-fbo '(0 :dimensions (256 256))))
  (sh1 (sample (attachment-tex h1 0)))
  (h2 (make-fbo '(0 :dimensions (128 128))))
  (sh2 (sample (attachment-tex h2 0)))
  (h3 (make-fbo '(0 :dimensions (64 64))))
  (sh3 (sample (attachment-tex h3 0))))

(defun bloom (stream sx)
  (map-g-into (fbos-c0 fbos) #'blit stream :tex sx)
  (map-g-into (fbos-c1 fbos) #'blit stream :tex sx)
  (map-g-into (fbos-c2 fbos) #'blit stream :tex sx)
  (map-g-into (fbos-c3 fbos) #'blit stream :tex sx)
  (map-g-into (fbos-h0 fbos) #'smooth stream
	      :tex (fbos-sc0 fbos) :offset (v! (/ 1.2 512) 0))
  (map-g-into (fbos-h1 fbos) #'smooth stream
	      :tex (fbos-sc1 fbos) :offset (v! (/ 1.2 256) 0))
  (map-g-into (fbos-h2 fbos) #'smooth stream
	      :tex (fbos-sc2 fbos) :offset (v! (/ 1.2 128) 0))
  (map-g-into (fbos-h3 fbos) #'smooth stream
	      :tex (fbos-sc3 fbos) :offset (v! (/ 1.2 64) 0))
  (map-g-into (fbos-c0 fbos) #'smooth stream
	      :tex (fbos-sh0 fbos) :offset (v! 0 (/ 1.2 512)))
  (map-g-into (fbos-c1 fbos) #'smooth stream
	      :tex (fbos-sh1 fbos) :offset (v! 0 (/ 1.2 256)))
  (map-g-into (fbos-c2 fbos) #'smooth stream
	      :tex (fbos-sh2 fbos) :offset (v! 0 (/ 1.2 128)))
  (map-g-into (fbos-c3 fbos) #'smooth stream
	      :tex (fbos-sh3 fbos) :offset (v! 0 (/ 1.2 64)))
  (map-g #'combine stream
	 :t0 (fbos-sc0 fbos) :t1 (fbos-sc1 fbos)
	 :t2 (fbos-sc2 fbos) :t3 (fbos-sc3 fbos)
	 :scale-effect (abs (sin *loop*))))

(defun step-demo ()
  (incf *loop* 0.01)
  (step-host)
  (update-repl-link)
  (clear)
  (bloom *quad-stream* cols-sampler)
  (swap))

;;-------------------------------------------------------
(defparameter *running* nil)

(defun run-loop ()
  (setf *running* t)
  (unless cols
    (setf cols (cepl.sdl2-image:load-image-to-texture
                (merge-pathnames "ThickCloudsWater/front.png" *examples-dir*)))
    (setf cols-sampler (sample cols)))
  (loop :while *running* :do (continuable (step-demo))))

(defun stop-loop ()
  (setf *running* nil))
