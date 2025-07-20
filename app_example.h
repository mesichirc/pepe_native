#ifndef APP_EXAMPLE
#define APP_EXAMPLE


// ios-colors
Clay_Color mint  = {0, 200, 179, 255};
Clay_Color black = {0, 0, 0, 255};
Clay_Color gray6 = {28, 28, 30, 255};
Clay_Color red   = {255, 66, 69, 255};
Clay_Color blue  = {0, 145, 255, 255};
Clay_Color green = {48, 209, 88, 255};
Clay_Color yellow = {255, 214, 0, 255};

i32
itoa(u32 x, u8 *buf)
{
  int	ndigits = 0, rx = 0, i = 0;

  if (x == 0) {
    buf[0] = '0';
    return 1;
  } else {
    while (x > 0) {
      rx = (10 * rx) + (x % 10);
      x /= 10;
      ++ndigits;
    }

    while (ndigits > 0) {
      buf[i++] = (rx % 10) + '0';
      rx /= 10;
      --ndigits;
    }
  }  
  return i;
}


typedef struct RecyclerContextDefinition RecyclerContextDefinition;
struct RecyclerContextDefinition {
  Clay_String label;
  u32 count;
  f32 cellSize;
  u32 containerToCell;
  bool isVertical;
};

typedef struct RecyclerContext RecyclerContext;
struct RecyclerContext {
  u32 count;
  u32 cells;
  u32 index;
  f32 cellIndex;
  f32 containerToCellsRatio;
  f32 cellSize;
  f32 containerSize;
  Clay_ElementId containerId;
  Clay_ElementId previousId;
  bool isVertical;
};

typedef struct RecyclerItem RecyclerItem;
struct RecyclerItem {
  Clay_ElementId  id;
  i32             index;
};

#define RECYCLE_ITEM_VALID(ritem) ((ritem).index >= 0)

RecyclerContext Recycler_init(RecyclerContextDefinition definition);
RecyclerItem Recycler_getNext(RecyclerContext *ctx, Clay_Vector2 offset);

typedef struct TapState TapState;
struct TapState {
  Clay_Vector2 point;
  i32 isPressed;
};

static TapState tapState;


typedef struct IOSAppContext IOSAppContext;
struct IOSAppContext {
  u8 buttonSize;
};

IOSAppContext appContext = {.buttonSize = 255};

typedef struct MobileStyle MobileStyle;
struct MobileStyle {
  f32 scale;
  f32 rotation;
  f32 opacity;
};

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(x, y) ((x) > (y) ? (x) : (y))

void HandleRendererButtonInteraction(Clay_ElementId elementId, Clay_PointerData pointerInfo, intptr_t userData) {
  unused(elementId);
  unused(userData);
  if (pointerInfo.state == CLAY_POINTER_DATA_PRESSED_THIS_FRAME || pointerInfo.state == CLAY_POINTER_DATA_PRESSED) {
    appContext.buttonSize = max(200, appContext.buttonSize - 10);
  }
}

#define STRING_SLICE(string, size) (CLAY__INIT(Clay_String) { .isStaticallyAllocated = true, .length = size, .chars = (string) })

u8 str[1024] = {0};

Clay_RenderCommandArray 
IOS_layout(void)
{
  memset(str, 0, 1024);
  i32 stroffset = 0;

  Clay_SetPointerState(tapState.point, tapState.isPressed > 2);
  if (tapState.isPressed > 0 && tapState.isPressed <= 2) {
    tapState.isPressed--;
  } else if (tapState.isPressed == 0) {
    tapState.point.x = 0.0f;
    tapState.point.y = 0.0f;
  }
   
  Clay_BeginLayout();
  Clay_Sizing layoutExpand = {
    .width = CLAY_SIZING_GROW(0),
    .height = CLAY_SIZING_GROW(0)
  };


  unused(layoutExpand);

  CLAY({ 
      .id = CLAY_ID("OuterContainer"), 
      .layout = { 
        .sizing = {CLAY_SIZING_GROW(0), CLAY_SIZING_GROW(0)}, 
        .childAlignment = { .y = CLAY_ALIGN_Y_CENTER, .x = CLAY_ALIGN_X_CENTER },
        .layoutDirection = CLAY_TOP_TO_BOTTOM,
        .padding = {.top = 56 }
      }, 
      .backgroundColor = gray6 
  }) {
    
    RecyclerContext recyclerContext = Recycler_init((RecyclerContextDefinition) {
      .label = CLAY_STRING("recycler"),
      .count = 16,
      .containerToCell = 2,
      .isVertical = true
    });

    CLAY({
      .id = recyclerContext.containerId,
      .layout = {
        .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_GROW(0) },
        .layoutDirection = CLAY_TOP_TO_BOTTOM,
      },
      .backgroundColor = black,
      .clip = { .vertical = true },
      .cornerRadius = {.topLeft = 8.0, .topRight = 8.0, .bottomLeft = 16.0, .bottomRight = 16.0 }
    }) {
      RecyclerItem item = Recycler_getNext(&recyclerContext, Clay_GetScrollOffset());
      while (RECYCLE_ITEM_VALID(item)) {
        CLAY({
          .id = item.id,
          .layout = {
            .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_FIXED(200) }
          },
          .backgroundColor = {255, 255, 255, 255 - item.index * 15}
        }) {   

            u32 offset = itoa(item.index, str + stroffset);
            printf("offset = %d, str %s\n", offset, str + stroffset);
            Clay_String label = (Clay_String) { .length = offset, .chars = (const char *)(str + stroffset) };
            stroffset += offset;
            stroffset++;

            offset = itoa(recyclerContext.cellIndex, str + stroffset);
            Clay_String cellIndexLabel = (Clay_String) { .length = offset, .chars = (const char *)(str + stroffset) };
            stroffset += offset;
            stroffset++;

            CLAY_TEXT(label, CLAY_TEXT_CONFIG({
              .fontId = 1,
              .fontSize = 24,
              .textColor = gray6
            }));
            CLAY_TEXT(cellIndexLabel, CLAY_TEXT_CONFIG({
              .fontId = 1,
              .fontSize = 24,
              .textColor = gray6
            }));
        }
        item = Recycler_getNext(&recyclerContext, Clay_GetScrollOffset());
      }  
    }
  }
    

  return Clay_EndLayout();
}


// RECYCLER VIEW

RecyclerContext
Recycler_init(RecyclerContextDefinition definition)
{
  RecyclerContext recyclerContext = {0};

  recyclerContext.containerId = CLAY_SID_LOCAL(definition.label);
  recyclerContext.count = definition.count;
  recyclerContext.cellSize = definition.cellSize;
  recyclerContext.containerToCellsRatio = (f32)definition.containerToCell;
  recyclerContext.isVertical = definition.isVertical;
  recyclerContext.cellIndex = 0;

  return recyclerContext;
}


struct RecyclerView {
  Clay_Vector2 (* getSize)(void);
  void (* setProperties)(UIView * view);
};

#define RECYCLER_ITEM_SIZE(ctx, elementData) (((ctx)->isVertical) ? (elementData).boundingBox.height : (elementData).boundingBox.width)

// TODO: try dynamically resize recycler container
RecyclerItem
Recycler_getNext(RecyclerContext *ctx, Clay_Vector2 offset)
{
  RecyclerItem recyclerItem = {0};
  recyclerItem.index = -1;
  assert(ctx);
  recyclerItem.id = CLAY_SIDI(ctx->containerId.stringId, ctx->cellIndex + 1);

  Clay_ElementData containerData = Clay_GetElementData(ctx->containerId);
  if (RECYCLER_ITEM_SIZE(ctx, containerData) > 0) {
    ctx->containerSize = RECYCLER_ITEM_SIZE(ctx, containerData);
  }

  Clay_ElementData elementData = Clay_GetElementData(ctx->previousId);
  if (elementData.found && RECYCLER_ITEM_SIZE(ctx, elementData) > 0) {
    ctx->cellSize = RECYCLER_ITEM_SIZE(ctx, elementData);
  }
  
  // measure part
  if ((ctx->containerSize == 0 || ctx->cellSize == 0) && ctx->index > 0) {
    return recyclerItem;
  }

  ctx->cells = (u32)(ctx->containerSize * (f32)ctx->containerToCellsRatio / ctx->cellSize);
  f32 offsetValue = ctx->isVertical ? offset.y : offset.x;
  i32 indexOffset = (i32)(offsetValue / ctx->cellSize);

  if (ctx->index >= ctx->count || ctx->cellIndex >= ctx->cells) {
    return recyclerItem;
  }

  recyclerItem.index = (i32)ctx->index;

  ctx->previousId = recyclerItem.id;

  if (ctx->containerSize == 0 || ctx->cellSize == 0) {
    ctx->index = 1;
    ctx->cellIndex = 1;
    ctx->previousId = recyclerItem.id;
    ctx->cells = 1;

    recyclerItem.index = 0;
    return recyclerItem;
  }

  ctx->index = ((ctx->index + 1) % ctx->cells) + indexOffset;
  ctx->cellIndex++;
  
  
  return recyclerItem;
}


#endif
