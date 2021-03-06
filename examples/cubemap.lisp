(in-package :cepl.examples+camera)

(defparameter tx nil)
(defparameter sampler nil)
(defparameter strm nil)
(defparameter cam nil)

(defun-g cube-vert ((vert :vec3) &uniform (mod-clip :mat4))
  (values (* mod-clip (v! vert 1))
          vert))

(defun-g cube-frag ((tc :vec3) &uniform (tex :sampler-cube))
  (texture tex tc))

(def-g-> skybox () #'cube-vert #'cube-frag)

(defun make-cubemap-tex (&rest paths)
  (with-c-arrays (ca (mapcar (lambda (p)
                               (cepl.sdl2-image:load-image-to-c-array
                                (merge-pathnames p *examples-dir*)))
                             paths))
    (make-texture ca :element-type :rgb8 :cubes t)))

(defun init ()
  (setf tx (make-cubemap-tex "ThickCloudsWater/left.png"
                             "ThickCloudsWater/right.png"
                             "ThickCloudsWater/up.png"
                             "ThickCloudsWater/down.png"
                             "ThickCloudsWater/front.png"
                             "ThickCloudsWater/back.png"))
  (setf sampler (sample tx))
  (let* ((bx (dendrite.primitives:box-data))
         (data (make-gpu-array (first bx) :element-type 'g-pnt))
         (ind (make-gpu-array (dendrite.primitives:swap-winding-order (second bx))
                              :element-type :ushort)))
    (setf strm (make-buffer-stream data :index-array ind
                                   :retain-arrays t)))
  (setf cam (make-camera)))

(defun step-demo ()
  (clear)
  (map-g #'skybox strm
	 :tex sampler :mod-clip (m4:* (cam->clip cam) (world->cam cam)))
  (swap))

(defparameter mouse-ang (v! 0 0))

(defun mouse-callback (event &rest ignored)
  (declare (ignore ignored))
  (let ((d (skitter:xy-pos-relative event)))
    (setf mouse-ang (v2:+ (v! (/ (v:x d) -150.0)
			      (/ (v:y d) -150.0))
			  mouse-ang))
    (setf (dir cam) (v! (sin (v:x mouse-ang))
			(sin (v:y mouse-ang))
			(cos (v:x mouse-ang))))))

(let ((running nil))
  (defun run-loop ()
    (init)
    (setf running t)
    (format t "-starting-")
    (skitter:whilst-listening-to ((#'mouse-callback (skitter:mouse 0) :pos))
      (loop :while running
	 :do (continuable
	       (update-repl-link)
	       (step-host)
	       (step-demo))))
    (print "-shutting down-")
    nil)
  (defun stop-loop () (setf running nil)))
