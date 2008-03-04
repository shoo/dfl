// Written by Christopher E. Miller
// See the included license.txt for copyright and license details.


///
module dfl.imagelist;

import dfl.base, dfl.drawing, dfl.internal.winapi;
import dfl.collections;


///
class ImageList // docmain
{
	///
	class ImageCollection
	{
		protected this()
		{
		}
		
		
		void insert(int index, Image img)
		{
			if(index >= _images.length)
			{
				add(img);
			}
			else
			{
				assert(0, "Must add images to the end of the image list");
			}
		}
		
		
		package:
		
		Image[] _images;
		
		
		void _adding(size_t idx, Image val)
		{
			assert(val !is null);
			
			switch(val._imgtype(null))
			{
				case 1:
				case 2:
					break;
				default:
					debug
					{
						assert(0, "Image list: invalid image type");
					}
					_unableimg();
			}
			
			if(val.size != imageSize)
			{
				debug
				{
					assert(0, "Image list: invalid image size");
				}
				_unableimg();
			}
		}
		
		
		void _added(size_t idx, Image val)
		{
			if(isHandleCreated)
			{
				//if(idx >= _images.length) // Can't test for this here because -val- is already added to the array.
				_addimg(val);
			}
		}
		
		
		void _removed(size_t idx, Image val)
		{
			if(isHandleCreated)
			{
				if(size_t.max == idx) // Clear all.
				{
					imageListRemove(handle, -1);
				}
				else
				{
					imageListRemove(handle, idx);
				}
			}
		}
		
		
		public:
		
		mixin ListWrapArray!(Image, _images,
			_adding, _added,
			_blankListCallback!(Image), _removed,
			false, false, false);
	}
	
	
	this()
	{
		InitCommonControls();
		
		_cimages = new ImageCollection();
		_transcolor = Color.transparent;
	}
	
	
	///
	final void colorDepth(ColorDepth depth) // setter
	{
		assert(!isHandleCreated);
		
		this._depth = depth;
	}
	
	/// ditto
	final ColorDepth colorDepth() // getter
	{
		return _depth;
	}
	
	
	///
	final void transparentColor(Color tc) // setter
	{
		assert(!isHandleCreated);
		
		_transcolor = tc;
	}
	
	/// ditto
	final Color transparentColor() // getter
	{
		return _transcolor;
	}
	
	
	///
	final void imageSize(Size sz) // setter
	{
		assert(!isHandleCreated);
		
		_w = sz.width;
		_h = sz.height;
	}
	
	/// ditto
	final Size imageSize() // getter
	{
		return Size(_w, _h);
	}
	
	
	///
	final ImageCollection images() // getter
	{
		return _cimages;
	}
	
	
	///
	final void tag(Object t) // setter
	{
		this._tag = t;
	}
	
	/// ditto
	final Object tag() // getter
	{
		return this._tag;
	}
	
	
	/+ // Actually, forget about these; just draw with the actual images.
	///
	final void draw(Graphics g, Point pt, int index)
	{
		return draw(g, pt.x, pt.y, index);
	}
	
	/// ditto
	final void draw(Graphics g, int x, int y, int index)
	{
		imageListDraw(handle, index, g.handle, x, y, ILD_NORMAL);
	}
	
	/// ditto
	// stretch
	final void draw(Graphics g, int x, int y, int width, int height, int index)
	{
		// ImageList_DrawEx operates differently if the width or height is zero
		// so bail out if zero and pretend the zero size image was drawn.
		if(!width)
			return;
		if(!height)
			return;
		
		imageListDrawEx(handle, index, g.handle, x, y, width, height,
			CLR_NONE, CLR_NONE, ILD_NORMAL); // ?
	}
	+/
	
	
	///
	final bool isHandleCreated() // getter
	{
		return HIMAGELIST.init != _hil;
	}
	
	deprecated alias isHandleCreated handleCreated;
	
	
	///
	final HIMAGELIST handle() // getter
	{
		if(!isHandleCreated)
			_createimagelist();
		return _hil;
	}
	
	
	///
	void dispose()
	{
		return dispose(true);
	}
	
	/// ditto
	void dispose(bool disposing)
	{
		if(isHandleCreated)
			imageListDestroy(_hil);
		_hil = HIMAGELIST.init;
		
		if(disposing)
		{
			//_cimages._images = null; // Not GC-safe in dtor.
			//_cimages = null; // Could cause bad things.
		}
	}
	
	
	~this()
	{
		dispose();
	}
	
	
	private:
	
	ColorDepth _depth = ColorDepth.DEPTH_8BIT;
	Color _transcolor;
	ImageCollection _cimages;
	HIMAGELIST _hil;
	int _w = 16, _h = 16;
	Object _tag;
	
	
	void _createimagelist()
	{
		if(isHandleCreated)
		{
			imageListDestroy(_hil);
			_hil = HIMAGELIST.init;
		}
		
		UINT flags = ILC_MASK;
		switch(_depth)
		{
			case ColorDepth.DEPTH_4BIT:          flags |= ILC_COLOR4;  break;
			default: case ColorDepth.DEPTH_8BIT: flags |= ILC_COLOR8;  break;
			case ColorDepth.DEPTH_16BIT:         flags |= ILC_COLOR16; break;
			case ColorDepth.DEPTH_24BIT:         flags |= ILC_COLOR24; break;
			case ColorDepth.DEPTH_32BIT:         flags |= ILC_COLOR32; break;
		}
		
		// Note: cGrow is not a limit, but how many images to preallocate each grow.
		_hil = imageListCreate(_w, _h, flags, _cimages._images.length, 4 + _cimages._images.length / 4);
		if(!_hil)
			throw new Exception("Unable to create image list");
		
		foreach(img; _cimages._images)
		{
			_addimg(img);
		}
	}
	
	
	void _unableimg()
	{
		throw new DflException("Unable to add image to image list");
	}
	
	
	void _addimg(Image img)
	{
		assert(isHandleCreated);
		
		HGDIOBJ hgo;
		int result;
		switch(img._imgtype(&hgo))
		{
			case 1:
				{
					COLORREF cr;
					if(_transcolor == Color.empty
						|| _transcolor == Color.transparent)
					{
						cr = CLR_NONE; // ?
					}
					else
					{
						cr = _transcolor.toRgb();
					}
					result = imageListAddMasked(_hil, cast(HBITMAP)hgo, cr);
				}
				break;
			
			case 2:
				result = imageListAddIcon(_hil, cast(HICON)hgo);
				break;
			
			default:
				result = -1;
		}
		
		//if(-1 == result)
		//	_unableimg();
	}
}


private extern(Windows)
{
	// This was the only way I could figure out how to use the current actctx (Windows issue).
	
	HIMAGELIST imageListCreate(
		int cx, int cy, UINT flags, int cInitial, int cGrow)
	{
		alias typeof(&ImageList_Create) TProc;
		static TProc proc = null;
		if(!proc)
			proc = cast(typeof(proc))GetProcAddress(GetModuleHandleA("comctl32.dll"), "ImageList_Create");
		return proc(cx, cy, flags, cInitial, cGrow);
	}
	
	int imageListAddIcon(
		HIMAGELIST himl, HICON hicon)
	{
		alias typeof(&ImageList_AddIcon) TProc;
		static TProc proc = null;
		if(!proc)
			proc = cast(typeof(proc))GetProcAddress(GetModuleHandleA("comctl32.dll"), "ImageList_AddIcon");
		return proc(himl, hicon);
	}
	
	int imageListAddMasked(
		HIMAGELIST himl, HBITMAP hbmImage, COLORREF crMask)
	{
		alias typeof(&ImageList_AddMasked) TProc;
		static TProc proc = null;
		if(!proc)
			proc = cast(typeof(proc))GetProcAddress(GetModuleHandleA("comctl32.dll"), "ImageList_AddMasked");
		return proc(himl, hbmImage, crMask);
	}
	
	BOOL imageListRemove(
		HIMAGELIST himl, int i)
	{
		alias typeof(&ImageList_Remove) TProc;
		static TProc proc = null;
		if(!proc)
			proc = cast(typeof(proc))GetProcAddress(GetModuleHandleA("comctl32.dll"), "ImageList_Remove");
		return proc(himl, i);
	}
	
	BOOL imageListDestroy(
		HIMAGELIST himl)
	{
		alias typeof(&ImageList_Destroy) TProc;
		static TProc proc = null;
		if(!proc)
			proc = cast(typeof(proc))GetProcAddress(GetModuleHandleA("comctl32.dll"), "ImageList_Destroy");
		return proc(himl);
	}
}

