from godot import exposed, export
from godot import *
#from skimage import filters, transform, io, util, color
from PIL import Image as pimg, ImageDraw as pdraw
import numpy as np

@exposed
class new_script(Node):

	# member variables here, example:
	a = export(int)
	b = export(str, default='foo')
	image = export(PoolByteArray)
	image_shape = export(Array)
	theoretical_image = export(Image)
	
	
	#main = self.get_node("/root/adamantrisChromaChalk")
	
	color_slot = export(int, default=7)
	unique_colors = np.empty((0, 3), dtype=np.uint8)
	lookup_img_size = 512
	lookup_img = pimg.new("RGB", (lookup_img_size, lookup_img_size))
	
	def _ready(self):
		"""
		Called every time the node is added to the scene.
		Initialization here.
		"""
		self.name = "Python_Processor"
		self.b = "fuck"
		print("oh hello there this is from ur mod")
		
		
	def load_img(self, path):
		
		pilimage = pimg.open(str(path))
		pilimage_resize = pilimage.resize((200, 200))
		pilimage_quantized = pilimage_resize.quantize(256)
		pilimage_conv = pilimage_quantized.convert("RGB")

		image_array = np.array(pilimage_conv)
		
		
		img_h, img_w, img_c = image_array.shape
		self.image_shape = Array([img_w, img_h, img_c])
		
		self.image = PoolByteArray(image_array.tobytes())
		print("HELLO THIS IS PYTHON CALLING, THIS IS THE ARRAY SHAPE ", self.image_shape)
#		print("HELLO THIS IS PYTHON CALLING, THIS IS YOUR NUMPY LOADED IMAGE WEIRDNESS", image.astype(np.int64))
		self.theoretical_image = Image()
		
		self.theoretical_image.create_from_data(img_w, img_h, bool(False), Image.FORMAT_RGB8, self.image)
		
		loader_logic = self.get_node("/root/adamantrisChromaChalk/UI")
		loader_logic._on_loading_finished(self.theoretical_image)
		#print("HELLO THIS IS YOUR BEST FRIEND PYTHON AGAIN, THIS SHOULD HAVE TURNED THE NUMPY ARRAY INTO BYTES", converted_img)
		
		reshaped_img_array = image_array.reshape(-1, 3)
		print(f"HELLO POOKSTER THIS IS THE RESHAPED IMG ARRAY {reshaped_img_array}")
		self.color_diff(reshaped_img_array)
		
		
		texrect = self.get_node("/root/adamantrisChromaChalk/UI/test_py_img")
		texrect.create_set_tex(self.theoretical_image)
		pass

	def color_diff(self, entries):
		np_color_dict = np.unique(entries, axis=0).astype(np.uint8)
		py_color_array = np_color_dict.tolist() #what an awkward line
		
		new_set = set(map(tuple, py_color_array))
		old_set = set(map(tuple, self.unique_colors.tolist()))
		
		diff_set = new_set - old_set
		
		if diff_set:
			self.unique_colors = np.concatenate([self.unique_colors, np.array(list(diff_set))]) #i hate this
			print(f"did some nparray magick, new set shape: {self.unique_colors.shape}")
			
			self.process_array(diff_set)
			
		else:
			print(f"AAAAAAAAAA ITS EMPTY AAAA")
		
		

	def process_array(self, diff):
		
		for color in diff:
			r, g, b = color
			self.lookup_img.putpixel( (self.color_slot % 512, int(self.color_slot / 512) ), (r, g, b))
			self.color_slot += 1
		
		color_array = Array([Color(r / 255.0, g / 255.0, b / 255.0) for r, g, b in diff])
		new_lookup_img = np.array(self.lookup_img).astype(np.uint8).tobytes()
		lookup_img_poolbytes = PoolByteArray(new_lookup_img)
		
		main = self.get_node("/root/adamantrisChromaChalk")
		main.python_dict_testies(int(self.color_slot), color_array, lookup_img_poolbytes)

	def dict_testing(self, test_dict):
		for entry in list(test_dict):
			print("hi this is key from test dict", type(str(entry)))
		print("hi this is the value", type(test_dict["test_entry"]))
