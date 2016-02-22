(in-package :cepl.examples+camera)

;;- - - - - - - - - - - - - - - - - -

(defvar box-data nil)
(defvar box-index nil)
(defvar box-stream nil)
(defvar brick nil)

(defstruct box
  (pos (v! 0 0 -10))
  (rot (q:identity)))

(defvar box-a (make-box :pos (v! 0 0 -5)))
(defvar box-b (make-box :pos (v! 0.3 0 -3)))

;;- - - - - - - - - - - - - - - - - -

(defun model->world (x)
  (m4:* (m4:translation (box-pos x)) (q:to-mat4 (box-rot x))))

(defun world->clip (c)
  (m4:* (cam->clip c) (world->cam c)))

(defun model->clip (m c)
  (m4:* (world->clip c) (model->world m)))

;;- - - - - - - - - - - - - - - - - -

(defvar bp (make-blending-params))
(defvar camera (make-camera))
(defvar factor 0)

(defun-g box-vert ((vert g-pnt) &uniform (model->clip :mat4))
  (values (* model->clip (v! (pos vert) 1))
          (norm vert)
          (tex vert)))

(defun-g box-frag ((norm :vec3) (tc :vec2) &uniform (tex :sampler-2d) (fac :float))
  (v! (s~ (texture tex (* tc 1)) :xyz) fac))

(defpipeline draw-box () (g-> #'box-vert #'box-frag))

;;- - - - - - - - - - - - - - - - - -

(defun step-demo ()
  (incf factor 0.02)
  (setf (box-rot box-a) (q:from-axis-angle
                         (v! (sin factor) (cos factor) 1) 10)
        (box-rot box-b) (q:from-axis-angle
                         (v! (sin (/ factor 5)) (cos (/ factor -3)) 1) 10))
  (clear)
  (map-g #'draw-box box-stream
         :model->clip (model->clip box-a camera)
         :tex brick)
  (with-blending bp
    (map-g #'draw-box box-stream
           :model->clip (model->clip box-b camera)
           :tex brick
           :fac (+ 0.7 (* (sin factor) 0.3))))
  (swap))

;;- - - - - - - - - - - - - - - - - -

(defun init ()
  (destructuring-bind (d i) (dendrite.primitives:box-data)
    (setf box-data (make-gpu-array d :element-type 'g-pnt)
          box-index (make-gpu-array i :element-type :ushort)
          box-stream (make-buffer-stream box-data :index-array box-index)
          brick (cepl.devil:load-image-to-texture
                 (merge-pathnames "brick/col.png" *examples-dir*)))))

(let ((running t))
  (defun run-loop ()
    (init)
    (loop :while (and running (not (shutting-down-p))) :do
       (continuable
         (step-host)
         (update-repl-link)
         (step-demo))))
  (defun stop-loop () (setf running nil)))
