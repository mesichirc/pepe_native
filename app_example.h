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

void
itoa(u32 x, char *buf)
{
  int	ndigits = 0, rx = 0, i = 0;

  if (x == 0) {
    buf[0] = '0';
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
}

typedef struct RecyclerContext RecyclerContext;
struct RecyclerContext {
  u32 count;
  u32 cells;
  u32 index;
  u32 currentCell;
  u32 containerToCellsRatio;
  f32 cellsSize; 
  Clay_ElementId containerId;
  Clay_ElementId previousId;
  bool isVertical;
};

typedef struct RecyclerItem RecyclerItem;
struct RecyclerItem {
  Clay_ElementId  id;
  bool            valid;
  u32             index;
};

RecyclerContext BeginRecycler(Clay_String label, bool isVertical, u32 count);
RecyclerItem recyclerGetNext(RecyclerContext *ctx);

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

Clay_RenderCommandArray 
IOS_layout(void)
{
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
    Clay_Color buttonColor = {97,85,245,appContext.buttonSize};

    CLAY({
      .id = CLAY_ID("ButtonContainer"), 
      .layout = { 
        .sizing = {CLAY_SIZING_FIT(64, 100), CLAY_SIZING_FIT(64, 100)}, 
        .padding = CLAY_PADDING_ALL(16), 
        .childAlignment = { .y = CLAY_ALIGN_Y_CENTER, .x = CLAY_ALIGN_X_CENTER },
      }, 
      .cornerRadius = CLAY_CORNER_RADIUS(8),
      .backgroundColor = buttonColor,
    }) {
      if (!Clay_Hovered()) {
        appContext.buttonSize = min(255, appContext.buttonSize + 10);
      }

      Clay_OnHover(HandleRendererButtonInteraction, 0);
      CLAY_TEXT(CLAY_STRING("SOME TEXT"), CLAY_TEXT_CONFIG({
          .fontId = 0,
          .fontSize = 24,
          .textColor = black
      }));

    }
    CLAY({
      .id = CLAY_ID("SCROLL_VIEW"),
      .layout = {
        .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_GROW(0) },
        .layoutDirection = CLAY_TOP_TO_BOTTOM, 
        .childGap = 16,
      },
      .cornerRadius = {.topLeft = 10, .bottomRight = 24},
      .clip = {
        .vertical = true
      },
      .backgroundColor = {0, 200, 179, 255}
    }) {
      for (i32 i = 0; i < 32; i++) {
        CLAY({
          .id = CLAY_IDI("ScrollBOX", i),
          .layout = {
            .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_FIXED(64) },
          },
          .backgroundColor = { 203, 48, 245, 255 }
        });
      }
    }   
  }
    

  return Clay_EndLayout();
}


// RECYCLER VIEW

RecyclerContext
BeginRecycler(Clay_String label, bool isVertical, u32 count)
{
  RecyclerContext result = {0};
  result.count = count;
  result.isVertical = isVertical;
  result.index = 0;
  result.containerToCellsRatio = 2;
  result.containerId = CLAY_SID(label);

  return result;
}
// TODO: try dynamically resize recycler container
RecyclerItem
recyclerGetNext(RecyclerContext *ctx)
{
  RecyclerItem result = {0};
  assert(ctx);

  result.id = CLAY_SIDI(ctx->containerId.stringId, ctx->currentCell + 1);

  Clay_ElementData containerData = Clay_GetElementData(ctx->containerId);
  assert(containerData.found);
  f32 containerSize = ctx->isVertical ? containerData.boundingBox.height : containerData.boundingBox.width;

  if (ctx->index >= ctx->count || containerSize < 0.01) {
    return result;
  }
  result.index = ctx->index;


  if (containerSize * (f32)ctx->containerToCellsRatio <= (f32)ctx->cellsSize) {
    result.valid = true;
    ctx->currentCell = ctx->index % ctx->cells; 
  } else {
    Clay_ElementData elementData = Clay_GetElementData(ctx->previousId);
    assert(elementData.found || ctx->currentCell == 0);
    Clay_BoundingBox bbox = elementData.boundingBox;
    
    ctx->cells++;
    ctx->currentCell++;
    if (ctx->isVertical) {
      ctx->cellsSize += bbox.height;
    } else {
      ctx->cellsSize += bbox.width;
    }
    result.valid = true;
  }

  ctx->index++;
  ctx->previousId = result.id;
  
  return result;
}


#endif
