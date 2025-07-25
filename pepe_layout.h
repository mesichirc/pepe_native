#ifndef PEPE_LAYOUT_H
#define PEPE_LAYOUT_H

#define PEPE_ARRAY(T) struct { u32 length; u32 capacity; T *data; }

typedef struct Pepe_Color Pepe_Color;
struct Pepe_Color {
  u8 r;
  u8 g;
  u8 b;
  u8 a;
};

typedef struct Pepe_Point Pepe_Point;
struct Pepe_Point {
  u16 x;
  u16 y;
};

typedef struct Pepe_CornerRadius Pepe_CornerRadius;
struct Pepe_CornerRadius {
  u16 topLeft;
  u16 topRight;
  u16 bottomLeft;
  u16 bottomRight;
};

// TODO add more settings for text elements
typedef struct Pepe_TextElementConfig Pepe_TextElementConfig;
struct Pepe_TextElementConfig {
  u16 fontId;
  u16 fontSize;
  u16 letterSpacing;
  u16 lineHeight;
};

typedef struct Pepe_Size Pepe_Size;
struct Pepe_Size {
  u16 width;
  u16 height;
};

typedef struct Pepe_Frame Pepe_Frame;
struct Pepe_Frame {
  Pepe_Point origin;
  Pepe_Size  size;
};

typedef struct Pepe_Slice Pepe_Slice;
struct Pepe_Slice {
  void *base;
  u64  length;
  u64  capacity;
};

typedef struct Pepe_String Pepe_String;
struct Pepe_String {
  u8  *base;
  u64 length;
};

u64
Pepe_Strlen(char * str)
{
  char *s;
  for (s = (char *)str; *s; ++s)
    ;

  return (u64)(s - str);
}


#define PEPE_STRING_CONST(strliteral) ((Pepe_String) {.base = (u8 *)strliteral, .length = sizeof(strliteral) - 1})

inline Pepe_String
Pepe_UnsafeCString(char *str)
{
  Pepe_String result;

  result.base         = (u8 *)str;
  result.length       = Pepe_Strlen(str);
  
  return result;
}

Pepe_Slice
Pepe_SliceInit(void *ptr, u64 length)
{
  assert(ptr);
  Pepe_Slice slice = {0};

  slice.base = ptr;
  slice.length = slice.capacity = length;

  return slice;
}

// https://ru.wikipedia.org/wiki/MurmurHash2
#define mmix(h,k) { k *= m; k ^= k >> r; k *= m; h *= m; h ^= k; }

u32
Pepe_Murmur2AHash(Pepe_Slice slice, u32 seed)
{
  u32 m = 0x5bd1e995;
  i32 r = 24;
  u32 len = (u32)slice.length;
  u32 l = len;
  u8 *data = (u8 *)slice.base;
  u32 h = seed;
  u32 k;

  while (len >= 4) {
    k = *(u32 *)data;
    mmix(h, k);

    data += 4;
    len -= 4;
  }

  u32 t = 0;

  switch (len) {
    case 3: t ^= data[2] << 16;
    case 2: t ^= data[1] << 8;
    case 1: t ^= data[0];
  }

  mmix(h,t);
	mmix(h,l);

  h ^= h >> 13;
	h *= m;
	h ^= h >> 15;

  return h;
}

u32
Pepe_Murmur2AHashU32(u32 item, u32 seed)
{
  Pepe_Slice slice = Pepe_SliceInit(&item, sizeof(u32));

  return Pepe_Murmur2AHash(slice, seed);
}

u32
Pepe_Murmur2AHashString(Pepe_String str, u32 seed)
{
  Pepe_Slice slice = Pepe_SliceInit(str.base, str.length);
  return Pepe_Murmur2AHash(slice, seed);
}

// 8 pages in terms of ios or new android pages
// 32 pages in terms of old android or linux pages

typedef struct Pepe_Arena Pepe_Arena;
struct Pepe_Arena {
  u8    *buf;
  u64   size;
  u64   currentOffset;
  u64   previousOffset; 
};


void
Pepe_ArenaInit(Pepe_Arena *arena, Pepe_Slice slice)
{
  assert(arena);
  arena->previousOffset = 0;
  arena->currentOffset = 0;
  arena->size = slice.length;
  arena->buf  = (u8 *)slice.base;
}


#define IS_POWER_OF_TWO(x) (((x) & ((x) - 1)) == 0)

uptr 
Pepe_AlignForward(uptr ptr, u64 align)
{
  uptr p, a;

  assert(IS_POWER_OF_TWO(align));

  p = ptr;
  a = (uptr)align;

  return (p + (a - 1)) & ~(a - 1);
}

#define PEPE_PACKED_ENUM enum __attribute__((__packed__))

typedef PEPE_PACKED_ENUM Pepe_ErrorTypes {
  PEPE_ERROR_ARENA_MEMORY_NOT_ENOUGH,
} Pepe_ErrorTypes;


#ifndef PEPE_DEFAULT_ALIGNMENT
#define PEPE_DEFAULT_ALIGNMENT (2*sizeof(void *))
#endif

void*
Pepe_ArenaAllocAlign(Pepe_Arena *arena, u64 size, u64 align)
{
  uptr currentPointer = (uptr)arena->buf + (uptr)arena->currentOffset;
  uptr offset = Pepe_AlignForward(currentPointer, align);
  assert(arena->buf);
  offset -= (uptr)arena->buf;

  if ((offset + size) > arena->size) {
    return nil;
  }

  void *pointer = &arena->buf[offset];
  arena->previousOffset = offset;
  arena->currentOffset = offset + size;
  memset(pointer, 0, size);

  return pointer;
}

#define PEPE_ARENA_ALLOC(arenaPointer, size) Pepe_ArenaAllocAlign(arenaPointer, size, PEPE_DEFAULT_ALIGNMENT)
#define PEPE_NEW(arenaPointer, type) Pepe_ArenaAllocAlign(arenaPointer, sizeof(type), PEPE_DEFAULT_ALIGNMENT)
#define PEPE_ARENA_CLEAR(arenaPointer) do { \
  (arenaPointer)->previousOffset = 0;       \
  (arenaPointer)->currentOffset = 0;        \
} while(0)

typedef PEPE_PACKED_ENUM {
  PEPE_NONE,
  PEPE_RECT,
  PEPE_TEXT
} Pepe_CommandType;

typedef struct Pepe_TextConfigRef Pepe_TextConfigRef;
struct Pepe_TextConfigRef { u16 id };

typedef struct Pepe_Command Pepe_Command;
struct Pepe_Command {
  u32                 id;
  Pepe_CommandType    type;
  Pepe_Frame          frame;
  Pepe_Color          backgroundColor;
  Pepe_TextConfigRef  textConfigRef;
  Pepe_String         text;
};

typedef PEPE_PACKED_ENUM {
  PEPE_FRAME_TYPE_FIXED,  // known size 0
  PEPE_FRAME_TYPE_FIT,    // based on children sizes and layout direction 1
  PEPE_FRAME_TYPE_GROW    // occupy free space 2
} Pepet_FrameType;

typedef struct Pepe_ElementRef Pepe_ElementRef;
struct Pepe_ElementRef { u32 id };

typedef struct Pepe_Constraints Pepe_Constraints;
struct Pepe_Constraints {
  u16 minWidth;
  u16 maxWidth;
  u16 minHeight;
  u16 maxHeight;
};


typedef struct Pepe_ElementId Pepe_ElementId;
struct Pepe_ElementId { u32 id };

typedef struct Pepe_ElementDepthFirstIterator Pepe_ElementDepthFirstIterator;
struct Pepe_ElementDepthFirstIterator {
  Pepe_Context    *context; 
  Pepe_ElementRef currentElementRef;
  Pepe_ElementRef previousElementRef;
};

Pepe_ElementDepthFirstIterator
Pepe_ElementDepthFirstIteratorInit(Pepe_Context *context)
{
  Pepe_ElementDepthFirstIterator iterator;
  iterator.context = context;
  iterator.currentElementRef.id = 1;
  iterator.previousElementRef.id = 0;

  return iterator;
}

bool
Pepe_ElementDepthFirstIteratorHasNext(Pepe_ElementDepthFirstIterator *iterator)
{
  assert(iterator && iterator->context && iterator->context->elements.data);
  PEPE_ARRAY(Pepe_Element) elements;
  Pepe_Element *element;

  elements = iterator->context->elements;
  assert(iterator->currentElementRef.id < elements.length);
  element = elements.data + iterator->currentElementRef.id;

  return element->parentRef.id != 0 || element->jumpRef.id != 0 || element->lastChildRef.id != iterator->previousElementRef.id;
}


Pepe_Element *
Pepe_ElementDepthFirstIteratorGetNext(Pepe_ElementDepthFirstIterator *iterator)
{
  assert(iterator && iterator->context && iterator->context->elements.data);
  PEPE_ARRAY(Pepe_Element) elements;
  Pepe_Element *element;
  Pepe_ElementRef next;

  elements = iterator->context->elements;
  next = iterator->currentElementRef;
  while (next != 0) {
    assert(next.id < elements.length);
    element = elements.data + next.id;
    if (element->firstChildRef.id != 0 && element->lastChildRef.id != iterator->previousElementRef.id) {
      next = element->firstChildRef.id;
      if (element->firstChildRef.id == 0) {
        break;
      }
    } else if (element->jumpRef.id != 0) {
      next = element->jumpRef.id;
      if (element->firstChildRef.id == 0) {
        break;
      }
    } else {
      next = element->parent.id;
      break;
    }
  }

  assert(next.id < iterator->context->elements.length);
  iterator->previousElementRef = iterator->currentElementRef;
  iterator->currentElementRef = next;

  return iterator->context->elements.data + next.id;
}

Pepe_Element *
Pepe_GetElementByRef(Pepe_Context *context, Pepe_ElementRef ref)
{
  Pepe_Element *element;
  assert(context && context->elements.data);
  assert(context->elements.length < ref.id);

  return context->elements.data + ref.id;
}

void
Pepe_DebugGraphvizPrintLayoutTree(Pepe_Context *context)
{
  Pepe_Element *element;
  assert(context && context->elements.data);
  Pepe_ElementDepthFirstIteratorInit iterator;

  iterator = Pepe_ElementDepthFirstIteratorInit(context);

  print("digraph G {\n");

  while (Pepe_ElementDepthFirstIteratorHasNext(&iterator)) {
    element = Pepe_ElementDepthFirstIteratorGetNext(&iterator);
    if (element->parentRef.id != 0) {
      printf("%d -> %d;\n", Pepe_GetElementByRef(context, element->parentRef), element);
    }
  }

  print("}\n");
}

#define PEPE_ELEMENT_IS_LEAF(elementPtr) ((elementPtr)->childRef.id == 0)

void
Pepe_MeasureLeafElement(Pepe_Element *element, Pepe_Constraints constraints)
{
  // TODO
}

void
Pepe_CalculateConstraints(Pepe_Context *context, Pepe_Element *element, Pepe_Element *lastMeasuredChild)
{

}



void
Pepe_Measure(Pepe_Context *context)
{
  Pepe_Element *element;
  Pepe_ElementDepthFirstIterator iterator;
  Pepe_Constraints constraints;

  assert(context);


  iterator = Pepe_ElementDepthFirstIteratorInit(context);
  constraints.minWidth = 0;
  constraints.maxWidth = context->windowFrame.size.width;
  constraints.minHeight = 0;
  cosntraints.maxHeight = context->windowFrame.size.maxHeight;

  while(Pepe_ElementDepthFirstIteratorHasNext(&iterator)) {
    element = Pepe_ElementDepthFirstIteratorGetNext(&iterator);
    if (PEPE_ELEMENT_IS_LEAF(element)) {
      Pepe_MeasureLeafElement(element, constraints);
    } 
  }
}


// 2 - FIT
// 3 - GROW
// 4 - FIT
// 5 - GROW
// 6 - GROW
// 7 - GROW 
// 8 - FIT
// 2 firstChildRef = 4
// 2 lastChildRef  = 7
// 4 jumpRef = 8
// 8 jumpRef = 3
// 2 [3, 4, 5, 6, 7, 8] lastMeasuredChild - 1, measuredChildrenCount - 1
// 2 [3, 4, 5, 6, 7, 8] lastMeasuredChild - 5, measuredChildrenCount - 2
// 2 [3, 4, 5, 6, 7, 8] lastMeasuredChild > 0
//
//            |1| - (window size as constraints) ROW
//           /   \
//          2     6
//         /|\    | \ 
//        3 4 5   7  8
//          |     |   \
//          11    9   10
/////////////////////////////

typedef struct Pepe_DrawIterator Pepe_DrawIterator;
struct Pepe_DrawIterator {
  Pepe_Context *context;
  bool hasNext;
  Pepe_ElementRef currentElementRef; 
  Pepe_ElementRef previousElementRef;
};

Pepe_DrawIterator
Pepe_DrawIteratorInit(Pepe_Context *context)
{
  Pepe_DrawIterator iterator;
  iterator.hasNext = true;
  iterator.context = context;
  iterator.currentElement.id = 1;

  return iterator;
}

Pepe_Element *
Pepe_DrawIteratorGetNext(Pepe_DrawIterator *iterator)
{
  assert(iterator && iterator->context && iterator->context->elements.data);
  PEPE_ARRAY(Pepe_Element) elements;
  Pepe_Element *element;
  Pepe_Element *currentElement;
  Pepe_ElementRef next;

  next.id = iterator->currentElementRef.id;
  elements = iterator->context->elements;
  assert(iterator->currentElementRef.id < elements.length);
  currentElement = elements.data + iterator->currentElementRef.id;

  while (next.id != 0) {    
    if (currentElement->firstChildToDrawRef.id != 0 && currentElement->lastChildToDrawRef.id != iterator.previousElementRef.id) {
      iterator->previousElementRef.id = iterator.currentElementRef.id;
      iterator->currentElementRef.id = currentElement->firstChildToDrawRef.id;
      break;
    }
    if (currentElement->nextDrawRef.id != 0) {
      iterator->previousElementRef.id = iterator.currentElementRef.id;
      iterator->currentElementRef.id = currentElement->nextDrawRef.id;
      break;
    }
    
    iterator->currentElementRef.id = currentElement->parentRef.id;
    assert(iterator->currentElementRef.id < elements.length);
    currentElement = elements.data + iterator->currentElementRef.id;
    if (currentElement->parentRef.id == 0 && currentElement->lastChildToDrawRef.id == iterator->previousElementRef.id) {
      iterator->hasNext = false;
      break;
    }
  }

  return currentElement;
}

typedef struct Pepe_Element Pepe_Element;
struct Pepe_Element {
  Pepe_ElementId    id;
  Pepe_Frame        frame;
  Pepe_FrameType    frameType;
  Pepe_Color        backgroundColor;
  Pepe_CornerRadius corners;
  Pepe_String       text;
  Pepe_ElementRef   firstChildRef;
  Pepe_ElementRef   lastNonGrowRef;
  Pepe_ElementRef   lastChildRef;
  Pepe_ElementRef   jumpRef;
  Pepe_ElementRef   parentRef;

  Pepe_ElementRef   firstChildToDrawRef;
  Pepe_ElementRef   nextDrawRef;
  Pepe_ElementRef   lastChildToDrawRef;
  Pepe_Constraints  constraints;
};

typedef struct Pepe_Context Pepe_Context;
struct Pepe_Context {
  Pepe_Frame                          windowFrame;
  Pepe_Arena                          arena; 
  PEPE_ARRAY(Pepe_Command)            commands;
  PEPE_ARRAY(Pepe_TextElementConfig)  textConfigs;
  PEPE_ARRAY(Pepe_Element)            elements;
  PEPE_ARRAY(u32)                     openedElements;
};



#define PEPE_MAX_ELEMENTS_COUNT       8192
#define PEPE_MAX_COMMANDS_COUNT       8192
#define PEPE_MAX_TEXT_CONFIG_COUNT    4096
#define PEPE_REST_BUFFER              4096 * 3

#define PEPE_REQUERED_MEMORY() (PEPE_MAX_ELEMENTS_COUNT * sizeof(Pepe_Command) + PEPE_MAX_COMMANDS_COUNT * sizeof(Pepe_Command) + PEPE_MAX_TEXT_CONFIG_COUNT * sizeof(Pepe_TextElementConfig) + PEPE_MAX_ELEMENTS_COUNT * sizeof(u32) + PEPE_REST_BUFFER)

typedef struct Pepe_ContextDeclaration Pepe_ContextDeclaration;
struct Pepe_ContextDeclaration {
  Pepe_Slice memory;
  u32 maxElementsCount;
  u32 maxCommandsCount;
  u32 maxTextConfigCount;
};

void
Pepe_ContextDeclarationDefault(Pepe_ContextDeclaration *declaration)
{
  assert(declaration);

  declaration->maxElementsCount = declaration->maxElementsCount == 0 ? PEPE_MAX_ELEMENTS_COUNT : declaration->maxElementsCount;
  declaration->maxCommandsCount = declaration->maxCommandsCount == 0 ? PEPE_MAX_COMMANDS_COUNT : declaration->maxCommandsCount;
  declaration->maxTextConfigCount = declaration->maxTextConfigCount == 0 ? PEPE_MAX_ELEMENTS_COUNT : declaration->maxTextConfigCount;

}


Pepe_Context
Pepe_ContextInit(Pepe_ContextDeclaration declaration)
{
  assert(memory.base);
  Pepe_Context context = {0};
  Pepe_ArenaInit(&context.arena, memory);
  assert(context.arena.buf);

  Pepe_ContextDeclarationDefault(&declaration);

  context.commands.data = nil;
  context.commands.capacity = declaration.maxCommandsCount;

  context.textConfigs.data = nil;
  context.textConfigs.capacity = declaration.maxTextConfigCount;

  context.elements.data = nil;
  context.elements.capacity = declaration.maxElementsCount;

  context.openedElements.data = nil;
  context.openedElements.capacity = declaration.maxElementsCount;

  return context;
}

typedef struct Pepe_CustomLayout Pepe_CustomLayout;
struct Pepe_CustomLayout {
  void *userdata;
  // for each child provide constraints
  Pepe_Constraints (* produceConstraintsForChild)(Pepe_Context *context, Pepe_Element *element, Pepe_Element *child, void *userdata);
  // after measuring each children set itself sizes
  void (* setFrame)(Pepe_Context *context, Pepe_Element *element, void *userdata);
  // place children
  void (* placeChildren)(Pepe_Context *context, Pepe_Element *element, void *userdata);
};

void
Pepe_BeginLayout(Pepe_Context *context)
{
  PEPE_ARENA_CLEAR(&context->arena);
  assert(context->arena.buf);

  context->commands.data = PEPE_ARENA_ALLOC(&context->arena, context->commands.capacity);
  assert(context->commands.data);
  context->commands.length = 0;

  context->elements.data = PEPE_ARENA_ALLOC(&context->arena, context->elements.capacity);
  assert(context->elements.data);
  context->elements.length = 0;

  context->textConfigs.data = PEPE_ARENA_ALLOC(&context->arena, context->textConfigs.capacity);
  assert(context->textConfigs.data);
  context->textConfigs.length = 0;

  context->openedElements.data = PEPE_ARENA_ALLOC(&context->arena, context->openedElements.capacity);
  assert(context->openedElements.data);
  context->openedElements.length = 0;
}

typedef struct Pepe_CommandsIterator Pepe_CommandsIterator;
struct Pepe_CommandsIterator {
  Pepe_Command *ptr;
  u32 index;
  u32 length;
};

#define PEPE_COMMANDS_HAS_NEXT(iterator) ((iterator).index <= (iterator).length)

#define PEPE_COMMANDS_GET_NEXT(iterator) ((iterator).ptr[(iterator).index++])

// iterator pattern
// 1. init element variable
// 2. init iterator
// 3. pass to while loop ITERATOR_HAS_NEXT macro
// 3. assign elemnt to ITERATOR_GET_NEXT value 
// example:
// Pepe_Command el;
// Pepe_CommandsIterator iterator = Pepe_EndLayout(ctx);
// while (PEPE_COMMANDS_HAS_NEXT(iterator)) {
//  el = PEPE_COMMANDS_GET_NEXT(iterator);
//  ...do something...
// }
//
// or
//
// Pepe_Commands el;
// Pepe_CommandsIterator iterator = Pepe_EndLayout(ctx);
// PEPE_PROCESS_COMMANDS(iterator, el) {
//   ...do something...
// }

#define PEPE_PROCESS_COMMANDS(iterator, el) \
  for (el = PEPE_COMMANDS_GET_NEXT(iterator); PEPE_COMMANDS_HAS_NEXT(iterator); el = PEPE_COMMANDS_GET_NEXT(iterator))




Pepe_CommandsIterator
Pepe_EndLayout(Pepe_Context *ctx) 
{
  Pepe_CommandsIterator iterator = {0};

  iterator.length = ctx->commands.length;
  iterator.ptr    = ctx->commands.data;
  iterator.index  = 0;

  return iterator;
}

u32
Pepe_Id(Pepe_Context *ctx, Pepe_String str)
{
  u32 id = Pepe_Murmur2AHashString(str, ctx->previousId);
  ctx->previousId = id;
  return id;
}


void
Pepe_PushCommand(Pepe_Context *ctx, Pepe_Command cmd)
{
  assert(ctx->commands.length < ctx->commands.capacity);
  assert(ctx->commands.data);
  ctx->commands.data[ctx->commands.length++] = cmd;
}

void 
Pepe_OpenElement(Pepe_Context *context)
{
  assert(context);
  assert(context->elements.data);
  assert(context->elements.length < ctx->commands.capacity);
  context->elements.data[context->elements.length++] = 
     
}

#endif
