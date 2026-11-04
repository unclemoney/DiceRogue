@tool
class_name FoilsmithDepth
extends RefCounted
## Depth Anything V2 Small (Apache-2.0), the model the CLI and the web app estimate depth with, run
## on the GPU in compute shaders (the *.glsl next to this) for [FoilsmithCard]'s "Bake depth".
## Its weights are tools/export_depth_model.py's. A DINOv2 ViT-S/14 turns the picture into tokens,
## and a DPT head fuses four of its layers back into a picture of how near each pixel is.
##
## Needs a renderer with a RenderingDevice (Forward+ or Mobile): estimate() is null without one.

const WEIGHTS := "res://addons/foilsmith/depth/depth_anything_v2_small.bin"
const SIDE := 518      # the short side the model sees (the size it was trained at)
const MAX_LONG := 1036 # the long side is capped, so a very tall or wide picture stays quick
const PATCH := 14
const DIM := 384
const HEADS := 6
const BLOCKS := 12
const TAPS := [2, 5, 8, 11]          # the blocks the head reads (after the backbone's layer norm)
const NECK := [48, 96, 192, 384]
const FUSION := 64
const KERNELS := ["embed", "layernorm", "matmul", "attention", "conv", "deconv", "interp"]

static var _model: FoilsmithDepth   # estimate()'s, on the main thread (tools)
static var _worker: Worker      # estimate_async()'s
static var _busy := false
static var _retired: Array[Worker] = []   # released workers, until their threads are joined

var rd: RenderingDevice
var _weights: RID
var _offsets := {}     # tensor name -> [offset, length] in halves
var _shaders := {}     # kernel -> [shader, pipeline]
var _temp: Array[RID] = []   # this run's buffers and uniform sets

## The thread estimate_async runs on. A local RenderingDevice only works on the thread that made it,
## so one thread keeps the model, taking jobs in turn, until it's released.
class Worker:
	var thread := Thread.new()
	var mutex := Mutex.new()
	var sem := Semaphore.new()
	var jobs: Array[Callable] = []   # an invalid Callable: free the model and stop
	var model: FoilsmithDepth
	var tried := false   # loading the model was tried (null after: no GPU)

	func _init() -> void:
		thread.start(_loop)

	func push(job: Callable) -> void:
		mutex.lock()
		jobs.append(job)
		mutex.unlock()
		sem.post()

	func _loop() -> void:
		while true:
			sem.wait()
			mutex.lock()
			var job: Callable = jobs.pop_front()
			mutex.unlock()
			if not job.is_valid():
				if model:
					model._free()
				model = null
				FoilsmithDepth._join.call_deferred(self)
				return
			job.call(self)

	func get_model() -> FoilsmithDepth:
		if not tried:
			tried = true
			var m := FoilsmithDepth.new()
			model = m if m._init_gpu() else null
		return model

## estimate() on a worker thread, so the game keeps running: calls done(depth) on the main thread
## when it's finished (unless done's object has gone by then). then(depth) -> Image, if given, runs on
## the thread too, after it (slow follow-up work), and done gets its result. One at a time: false if
## one is already running.
static func estimate_async(img: Image, done: Callable, then := Callable()) -> bool:
	if _busy:
		return false
	_busy = true
	if _worker == null:
		_worker = Worker.new()
		# its device must be freed before the engine shuts the renderer down, or quitting crashes
		var root := (Engine.get_main_loop() as SceneTree).root
		if not root.tree_exiting.is_connected(_shutdown):
			root.tree_exiting.connect(_shutdown)
	_worker.push(func(w: Worker):
		var m := w.get_model()
		var d := m._estimate(img) if m else null
		if d != null and then.is_valid():
			d = then.call(d)
		_finish.call_deferred(d, done))
	return true

static func busy() -> bool:
	return _busy

static func _finish(depth: Image, done: Callable) -> void:
	_busy = false
	if done.is_valid():
		done.call(depth)

## The picture's depth as L8 at img's size, white = nearest (as Depth Anything's own maps, and the
## CLI's). Null when there's no GPU to run it on. Runs here and now; the editor uses estimate_async.
static func estimate(img: Image) -> Image:
	return _main_model()._estimate(img) if _main_model() else null

## The model's raw output for img: {w, h, depth (PackedFloat32Array, row-major, larger = nearer)} at
## the size it ran at, empty when there's no GPU. Runs here and now, like estimate.
static func predict(img: Image) -> Dictionary:
	return _main_model()._run(img) if _main_model() else {}

static func _main_model() -> FoilsmithDepth:
	if _model == null:
		var m := FoilsmithDepth.new()
		if m._init_gpu():
			_model = m
	return _model

## Frees the loaded models and their GPU memory (the next estimate loads one again). A job still
## running finishes first, on its thread, without holding up this one.
static func release() -> void:
	if _model:
		_model._free()
		_model = null
	if _worker:
		_worker.push(Callable())
		_retired.append(_worker)
		if not _busy:
			_join(_worker)   # only the freeing left to do: quick
		_worker = null

static func _join(w: Worker) -> void:
	if _retired.has(w):
		_retired.erase(w)
		w.thread.wait_to_finish()

## The game is quitting: waits for every worker to free its device.
static func _shutdown() -> void:
	release()
	for w in _retired.duplicate():
		_join(w)

func _free() -> void:
	if rd == null:
		return
	for k in _shaders:
		rd.free_rid(_shaders[k][0])   # its pipeline goes with it
	if _weights.is_valid():
		rd.free_rid(_weights)
	rd.free()

func _estimate(img: Image) -> Image:
	var raw := _run(img)
	var d: PackedFloat32Array = raw.depth
	var lo := INF
	var hi := -INF
	for v in d:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var out := Image.create_from_data(raw.w, raw.h, false, Image.FORMAT_RF, d.to_byte_array())
	out.resize(img.get_width(), img.get_height(), Image.INTERPOLATE_CUBIC)
	var f := out.get_data().to_float32_array()
	var bytes := PackedByteArray()
	bytes.resize(f.size())
	var k := 255.0 / maxf(hi - lo, 1e-5)
	for i in f.size():
		bytes[i] = clampi(int((f[i] - lo) * k), 0, 255)
	return Image.create_from_data(img.get_width(), img.get_height(), false, Image.FORMAT_L8, bytes)

## The size the model runs a w x h picture at: its short side SIDE (as transformers'
## DPTImageProcessor shrinks a big picture), both sides multiples of PATCH.
static func input_size(w: int, h: int) -> Vector2i:
	var s := float(SIDE) / mini(w, h)
	s = minf(s, float(MAX_LONG) / maxi(w, h))
	return Vector2i(maxi(1, roundi(w * s / PATCH)) * PATCH, maxi(1, roundi(h * s / PATCH)) * PATCH)

func _init_gpu() -> bool:
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		return false
	var f := FileAccess.open(WEIGHTS, FileAccess.READ)
	if f == null:
		push_error("FoilsmithDepth: can't open " + WEIGHTS)
		return false
	if f.get_buffer(4).get_string_from_ascii() != "DAV2":
		push_error("FoilsmithDepth: not a depth model: " + WEIGHTS)
		return false
	var count := f.get_32()
	for i in count:
		var name := f.get_buffer(f.get_16()).get_string_from_utf8()
		var off := f.get_32()
		_offsets[name] = [off, f.get_32()]
	var data := f.get_buffer(f.get_length() - f.get_position())
	data.resize((data.size() + 3) / 4 * 4)
	_weights = rd.storage_buffer_create(data.size(), data)
	for k in KERNELS:
		var file: RDShaderFile = load("res://addons/foilsmith/depth/%s.glsl" % k)
		var spirv := file.get_spirv()
		if spirv.compile_error_compute != "":
			push_error("FoilsmithDepth: %s: %s" % [k, spirv.compile_error_compute])
			return false
		var shader := rd.shader_create_from_spirv(spirv)
		_shaders[k] = [shader, rd.compute_pipeline_create(shader)]
	return true

func _w(name: String) -> int:
	return _offsets[name][0]

func _buf(floats: int) -> RID:
	var b := rd.storage_buffer_create(maxi(floats, 1) * 4)
	_temp.append(b)
	return b

## Queues one kernel over `groups` workgroups: its input a, output o and extra x (any may be the
## same dummy when unused), and its push constants.
func _go(kernel: String, a: RID, o: RID, x: RID, pc: Array, groups: Vector3i) -> void:
	var us: Array[RDUniform] = []
	for i in 4:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.binding = i
		u.add_id([_weights, a, o, x][i])
		us.append(u)
	var set := rd.uniform_set_create(us, _shaders[kernel][0], 0)
	_temp.append(set)
	var ints := PackedInt32Array(pc)
	while ints.size() % 4 != 0:
		ints.append(0)
	var bytes := ints.to_byte_array()
	var cl := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(cl, _shaders[kernel][1])
	rd.compute_list_bind_uniform_set(cl, set, 0)
	rd.compute_list_set_push_constant(cl, bytes, bytes.size())
	rd.compute_list_dispatch(cl, groups.x, groups.y, groups.z)
	rd.compute_list_end()

func _conv(a: RID, o: RID, cin: int, h: int, w: int, cout: int, k: int, stride: int, pad: int,
		weight: String, bias: String, flags := 0, x := RID()) -> Vector2i:
	var ho := (h + 2 * pad - k) / stride + 1
	var wo := (w + 2 * pad - k) / stride + 1
	_go("conv", a, o, x if x.is_valid() else a, [cin, h, w, cout, ho, wo, k, stride, pad, _w(weight),
		_w(bias) if bias != "" else -1, flags], Vector3i(ceili(wo / 8.0), ceili(ho / 8.0), cout))
	return Vector2i(wo, ho)

func _interp(a: RID, o: RID, c: int, from: Vector2i, to: Vector2i, align: bool) -> void:
	_go("interp", a, o, a, [c, from.y, from.x, to.y, to.x, 1 if align else 0],
		Vector3i(ceili(to.x / 8.0), ceili(to.y / 8.0), c))

## A pre-activation residual unit: out = conv(relu(conv(relu(a)))) + a, added onto out if `onto`.
func _rcu(a: RID, out: RID, size: Vector2i, name: String, onto := false) -> void:
	var t := _buf(FUSION * size.x * size.y)
	_conv(a, t, FUSION, size.y, size.x, FUSION, 3, 1, 1, name + ".convolution1.weight", name + ".convolution1.bias", 1)
	_conv(t, out, FUSION, size.y, size.x, FUSION, 3, 1, 1, name + ".convolution2.weight", name + ".convolution2.bias",
		1 | 4 | (8 if onto else 0), a)

func _run(img: Image) -> Dictionary:
	var size := input_size(img.get_width(), img.get_height())
	var pic := img.duplicate() as Image
	if pic.is_compressed():
		pic.decompress()
	pic.convert(Image.FORMAT_RGBA8)
	pic.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	var pw := size.x / PATCH
	var ph := size.y / PATCH
	var n := 1 + pw * ph
	var pixels := pic.get_data()
	var px := rd.storage_buffer_create(pixels.size(), pixels)
	_temp.append(px)

	# backbone: DINOv2 ViT-S/14
	var hid := _buf(n * DIM)
	_go("embed", px, hid, px, [ph, pw, _w("backbone.embeddings.patch_embeddings.projection.weight"),
		_w("backbone.embeddings.patch_embeddings.projection.bias"), _w("backbone.embeddings.cls_token"),
		_w("backbone.embeddings.position_embeddings"), 37], Vector3i(DIM / 64, ceili(n / 4.0), 1))
	var ln := _buf(n * DIM)
	var qkv := _buf(n * 3 * DIM)
	var att := _buf(n * DIM)
	var mlp := _buf(n * 4 * DIM)
	var taps: Array[RID] = []
	var rows := ceili(n / 64.0)
	for b in BLOCKS:
		var l := "backbone.encoder.layer.%d." % b
		_go("layernorm", hid, ln, hid, [n, _w(l + "norm1.weight"), _w(l + "norm1.bias")], Vector3i(rows, 1, 1))
		_go("matmul", ln, qkv, ln, [n, 3 * DIM, DIM, _w(l + "attention.qkv.weight"), _w(l + "attention.qkv.bias"), 0, 0],
			Vector3i(3 * DIM / 64, rows, 1))
		_go("attention", qkv, att, qkv, [n], Vector3i(rows, HEADS, 1))
		_go("matmul", att, hid, att, [n, DIM, DIM, _w(l + "attention.output.dense.weight"),
			_w(l + "attention.output.dense.bias"), 2, _w(l + "layer_scale1.lambda1")], Vector3i(DIM / 64, rows, 1))
		_go("layernorm", hid, ln, hid, [n, _w(l + "norm2.weight"), _w(l + "norm2.bias")], Vector3i(rows, 1, 1))
		_go("matmul", ln, mlp, ln, [n, 4 * DIM, DIM, _w(l + "mlp.fc1.weight"), _w(l + "mlp.fc1.bias"), 1, 0],
			Vector3i(4 * DIM / 64, rows, 1))
		_go("matmul", mlp, hid, mlp, [n, DIM, 4 * DIM, _w(l + "mlp.fc2.weight"), _w(l + "mlp.fc2.bias"), 2,
			_w(l + "layer_scale2.lambda1")], Vector3i(DIM / 64, rows, 1))
		if b in TAPS:
			var tap := _buf(n * DIM)
			_go("layernorm", hid, tap, hid, [n, _w("backbone.layernorm.weight"), _w("backbone.layernorm.bias")], Vector3i(rows, 1, 1))
			taps.append(tap)

	# neck: each tap reassembled into a feature map at its own scale (4x, 2x, 1x and 0.5x the patch grid)
	var grid := Vector2i(pw, ph)
	var feats: Array[RID] = []
	var sizes: Array[Vector2i] = []
	for i in 4:
		var r := "neck.reassemble_stage.layers.%d." % i
		var c: int = NECK[i]
		var proj := _buf(c * pw * ph)
		_conv(taps[i], proj, DIM, ph, pw, c, 1, 1, 0, r + "projection.weight", r + "projection.bias", 16)
		var map := proj
		var s := grid
		if i < 2:
			var f := 4 if i == 0 else 2
			s = grid * f
			map = _buf(c * s.x * s.y)
			_go("deconv", proj, map, proj, [c, ph, pw, f, _w(r + "resize.weight"), _w(r + "resize.bias")],
				Vector3i(ceili(s.x / 8.0), ceili(s.y / 8.0), c))
		elif i == 3:
			s = Vector2i((pw - 1) / 2 + 1, (ph - 1) / 2 + 1)
			map = _buf(c * s.x * s.y)
			_conv(proj, map, c, ph, pw, c, 3, 2, 1, r + "resize.weight", r + "resize.bias")
		var feat := _buf(FUSION * s.x * s.y)
		_conv(map, feat, c, s.y, s.x, FUSION, 3, 1, 1, "neck.convs.%d.weight" % i, "")
		feats.append(feat)
		sizes.append(s)

	# fusion, from the coarsest map up, each step upsampled to the next's size (the last doubled)
	var fused := RID()
	var fsize := Vector2i.ZERO
	for j in 4:
		var i := 3 - j
		var l := "neck.fusion_stage.layers.%d." % j
		var s := sizes[i]
		var cur := feats[i]
		if fused.is_valid():
			_rcu(feats[i], fused, s, l + "residual_layer1", true)   # fused += rcu(feature)
			cur = fused
		var rc := _buf(FUSION * s.x * s.y)
		_rcu(cur, rc, s, l + "residual_layer2")
		var to := sizes[i - 1] if i > 0 else s * 2
		var up := _buf(FUSION * to.x * to.y)
		_interp(rc, up, FUSION, s, to, true)
		fused = _buf(FUSION * to.x * to.y)
		_conv(up, fused, FUSION, to.y, to.x, FUSION, 1, 1, 0, l + "projection.weight", l + "projection.bias")
		fsize = to

	# head: halve the channels, upsample to the picture's size, then down to one channel of depth
	var h1 := _buf(FUSION / 2 * fsize.x * fsize.y)
	_conv(fused, h1, FUSION, fsize.y, fsize.x, FUSION / 2, 3, 1, 1, "head.conv1.weight", "head.conv1.bias")
	var up := _buf(FUSION / 2 * size.x * size.y)
	_interp(h1, up, FUSION / 2, fsize, size, true)
	var h2 := _buf(32 * size.x * size.y)
	_conv(up, h2, FUSION / 2, size.y, size.x, 32, 3, 1, 1, "head.conv2.weight", "head.conv2.bias", 2)
	var depth := _buf(size.x * size.y)
	_conv(h2, depth, 32, size.y, size.x, 1, 1, 1, 0, "head.conv3.weight", "head.conv3.bias", 2)

	rd.submit()
	rd.sync()
	var out := rd.buffer_get_data(depth).to_float32_array()
	for i in range(_temp.size() - 1, -1, -1):   # uniform sets before the buffers they use
		rd.free_rid(_temp[i])
	_temp.clear()
	return {"w": size.x, "h": size.y, "depth": out}
