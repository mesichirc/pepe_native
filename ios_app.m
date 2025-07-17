#include <QuartzCore/QuartzCore.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#define CLAY_IMPLEMENTATION
#include "./clay.h"
#include <stdint.h> // stdint's
#include <stdbool.h> // bool
#include <sys/mman.h> // for mmap
#include <assert.h> // for assert

#ifndef nil
#define nil (void *)0
#endif

typedef int8_t	i8;
typedef uint8_t	u8;
typedef uint8_t	byte;

typedef int16_t	i16;
typedef uint16_t	u16;

typedef int32_t	i32;
typedef uint32_t	u32;

typedef int64_t	i64;
typedef uint64_t	u64;

typedef float	f32;
typedef double f64;

typedef uintptr_t	uptr;

#define unused(x) (void)(x)



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

UIColor *
Clay_colorToUIColor(Clay_Color color)
{
  return  [UIColor colorWithRed:((f32)color.r / 255.0)
                          green:((f32)color.g / 255.0)
                           blue:((f32)color.b / 255.0)
                          alpha:((f32)color.a / 255.0)];
}


void
UIView_setBorderRadius(UIView *view, Clay_CornerRadius corners) {
  CGMutablePathRef path = CGPathCreateMutable();
  CGPoint topLeft = view.bounds.origin;
  CGPoint topRight = CGPointMake(view.bounds.origin.x + view.bounds.size.width, view.bounds.origin.y);
  CGPoint bottomLeft = CGPointMake(view.bounds.origin.x, view.bounds.origin.y + view.bounds.size.height);
  CGPoint bottomRight = CGPointMake(view.bounds.origin.x + view.bounds.size.width, view.bounds.origin.y + view.bounds.size.height);

  if (corners.topLeft != 0.0f) {
    CGPathMoveToPoint(path, nil, topLeft.x + corners.topLeft, topLeft.y);
  } else {
    CGPathMoveToPoint(path, nil, topLeft.x, topLeft.y);
  }

  if (corners.topRight != 0.0f) {
    CGPathAddLineToPoint(path, nil, topRight.x - corners.topRight, topRight.y);
    CGPathAddCurveToPoint(path, nil,  topRight.x, topRight.y, topRight.x, topRight.y + corners.topRight, topRight.x, topRight.y + corners.topRight);
  } else {
    CGPathMoveToPoint(path, nil, topRight.x, topRight.y);
  }

  if (corners.bottomRight != 0.0f) {
    CGPathAddLineToPoint(path, nil, bottomRight.x, bottomRight.y - corners.bottomRight);
    CGPathAddCurveToPoint(path, nil, bottomRight.x, bottomRight.y, bottomRight.x - corners.bottomRight, bottomRight.y, bottomRight.x - corners.bottomRight, bottomRight.y);
  } else {
    CGPathAddLineToPoint(path, nil, bottomRight.x, bottomRight.y);
  }

  if (corners.bottomLeft != 0.0f) {
    CGPathAddLineToPoint(path, nil, bottomLeft.x + corners.bottomLeft, bottomRight.y);
    CGPathAddCurveToPoint(path, nil, bottomLeft.x, bottomLeft.y, bottomLeft.x, bottomLeft.y - corners.bottomLeft, bottomLeft.x, bottomLeft.y - corners.bottomLeft);
  } else {
    CGPathAddLineToPoint(path, nil, bottomLeft.x, bottomRight.y);
  }

  if (corners.topLeft != 0.0f) {
    CGPathAddLineToPoint(path, nil, topLeft.x, topLeft.y + corners.topLeft);
    CGPathAddCurveToPoint(path, nil, topLeft.x, topLeft.y, topLeft.x + corners.topLeft, topLeft.y, topLeft.x + corners.topLeft, topLeft.y);
  } else {
    CGPathAddLineToPoint(path, nil, topLeft.x, topLeft.y);
  }
  CGPathCloseSubpath(path);
  CAShapeLayer* shape = [CAShapeLayer layer];
  shape.path = path;
  view.layer.mask = shape;
}

// TODO: Make different fonts available
static inline Clay_Dimensions 
IOS_MeasureText(Clay_StringSlice text, Clay_TextElementConfig *config, void *ud)
{
  unused(config);
  unused(ud);
  Clay_Dimensions textSize = { 0 };
  UIFont *font = [UIFont systemFontOfSize:config->fontSize];
  // TODO: remove allocation
  NSDictionary *attrs = @{
    NSFontAttributeName : font
  };
  
  NSString *str = [[NSString alloc] initWithBytesNoCopy:(void *)text.chars length:text.length encoding:NSUTF8StringEncoding freeWhenDone:NO];

  // TODO: remove allocation try to reuse attrstr, LRU ?;
  NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString:str attributes:attrs];

  CGSize size = [attrstr size];

  textSize.width = size.width;
  textSize.height = size.height;

  return textSize;
}

typedef struct AllocationPoint AllocationPoint;
struct AllocationPoint {
  f32 x;
  f32 y;
};

typedef struct ScissorItem ScissorItem;
struct ScissorItem {
  AllocationPoint   nextAllocation;
  UIView            *element;
  i32               nextElementIndex;
};

#define SCISSOR_STACK_LEN 256

typedef struct ScissorStack ScissorStack;
struct ScissorStack {
  ScissorItem data[SCISSOR_STACK_LEN];
  u64         len;
};

void
ScissorStack_push(ScissorStack *stack, ScissorItem item)
{
  assert(stack && stack->len < SCISSOR_STACK_LEN);
  stack->data[stack->len] = item;
  stack->len++;
}

ScissorItem
ScissorStack_pop(ScissorStack *stack)
{
  assert(stack && stack->len > 0);
  --stack->len;
  return stack->data[stack->len];
}

ScissorItem *
ScissorStack_get(ScissorStack *stack, u64 indx)
{
  assert(stack && stack->len > indx);
  return &stack->data[indx];
}

@interface ScrollView : UIScrollView
@property (strong, nonatomic) UIView *contentView;
@end

@implementation ScrollView
@end


@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;

@property (strong, nonatomic) NSMutableDictionary *elementsCache;
@property (strong, nonatomic) NSMutableDictionary *imageCache;
@property TapState tapState;

@end

bool
isMemoryEqual(void *src, u64 srcLen, void *dst, u64 dstLen)
{
  return srcLen == dstLen && Clay__MemCmp((const char*)src, (const char*)dst, (i32)srcLen);
}
static NSData *emptyData;
static NSString *emptyString;

NSMutableDictionary*
makeElementData(UIView *view)
{
  emptyData = [NSData dataWithBytes:nil length: 0];
  emptyString = @"";
  NSMutableDictionary *res = [[NSMutableDictionary alloc] init];
  res[@"view"] = view;
  res[@"exists"] = @YES;
  res[@"previousFrame"] = emptyData;
  res[@"previousConfig"] = emptyData;
  res[@"previousText"] = emptyString;
  
  return res;
}

#define min(a, b) ((a) < (b) ? (a) : (b))



UIView *
getContentView(UIView *view)
{
  if ([view isKindOfClass:[ScrollView class]]) {

    return ((ScrollView *)view).contentView;
  }
  return view;
}

void
IOS_Render(Clay_RenderCommandArray renderCommands,  AppDelegate *delegate) 
{
  if (nil == delegate.elementsCache) {
    delegate.elementsCache = [[NSMutableDictionary alloc] init];
  }
  ScissorStack scissorStack = {0};
  ScissorStack_push(&scissorStack, (ScissorItem) {
    .nextAllocation = {0, 0},
    .element = delegate.window.rootViewController.view,
    .nextElementIndex = 0,
  });

  u32 previousId = 0;

  for (i32 i = 0; i < renderCommands.length; i++) {
    ScissorItem *parentElementData    = &scissorStack.data[scissorStack.len - 1];
    UIView *parentElement             = parentElementData->element;
    Clay_RenderCommand *renderCommand = Clay_RenderCommandArray_Get(&renderCommands, i);
    Clay_BoundingBox bbox             = renderCommand->boundingBox;
    CGRect frame                      = CGRectMake(bbox.x, bbox.y, bbox.width, bbox.height);
    // TODO: use custom map instead of NSDictionary
    NSString *key                     = [NSString stringWithFormat:@"%d", renderCommand->id];
    bool isMultiConfigElement = previousId == renderCommand->id;
    Clay_ScrollContainerData scrollData = Clay_GetScrollContainerDataByIntID(renderCommand->id);   
    if (!delegate.elementsCache[key]) {

      // TODO: figure out scroll view and recycler view
      switch (renderCommand->commandType)
      {
        case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
          if (scrollData.found) {
              ScrollView *scrollView = [[ScrollView alloc] initWithFrame:frame];
            scrollView.contentView = [[UIView alloc] initWithFrame:scrollView.bounds];
            [scrollView addSubview:scrollView.contentView];
            delegate.elementsCache[key] = makeElementData(scrollView);
          } else {
            delegate.elementsCache[key] = makeElementData([[UIView alloc] initWithFrame:frame]);
          }

          break;
        }
        case CLAY_RENDER_COMMAND_TYPE_IMAGE: {
          delegate.elementsCache[key] = makeElementData([[UIImageView alloc] initWithFrame:frame]); 
          break;
        }
        case CLAY_RENDER_COMMAND_TYPE_TEXT: {
          delegate.elementsCache[key] = makeElementData([[UILabel alloc] initWithFrame:frame]);
          break;
        }
        default:
          break;
      }
    }

    NSMutableDictionary *elementData = delegate.elementsCache[key];
    UIView *element     = elementData[@"view"];
    element.tag = renderCommand->id;

    NSData *previousFrame = (NSData *)elementData[@"previousFrame"];

    bool isDirty = !(previousFrame != nil && isMemoryEqual((void *)previousFrame.bytes, previousFrame.length, (void *)&frame, sizeof(CGRect))) && !isMultiConfigElement;
    UIView *parentConentView = getContentView(parentElement);

    if (!isMultiConfigElement && (parentConentView.subviews.count == 0 || ((u64)[parentConentView.subviews indexOfObject:element] != (u64)parentElementData->nextElementIndex)) && element) {
      if (parentElementData->nextElementIndex == 0) {
        if (parentConentView.subviews.count == 0) {
          [parentConentView insertSubview:element atIndex:0];
        } else {
          [parentConentView addSubview:element];
        }
      } else {
        [element removeFromSuperview]; 
        [parentConentView insertSubview:element aboveSubview:parentConentView.subviews[(u64)(parentElementData->nextElementIndex - 1)]];
      }
    }

    if (!isMultiConfigElement) {
      parentElementData->nextElementIndex++;
    }
    previousId = renderCommand->id;
    elementData[@"exists"] = @YES;

    f32 offsetX = scissorStack.len > 0 ? parentElementData->nextAllocation.x : 0.0f;
    f32 offsetY = scissorStack.len > 0 ? parentElementData->nextAllocation.y : 0.0f;
    if (isDirty) {
      element.frame = CGRectMake(
        bbox.x - offsetX,
        bbox.y - offsetY,
        frame.size.width,
        frame.size.height
      );
    }

    switch (renderCommand->commandType) 
    { 
      case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
        Clay_RectangleRenderData *config = &renderCommand->renderData.rectangle;
        

        NSData *previousConfig = elementData[@"previousConfig"];
        if (isMemoryEqual((void *)previousConfig.bytes, previousConfig.length, (void *)config, sizeof(Clay_RectangleRenderData))) {
          break; 
        }

        UIView_setBorderRadius(element, config->cornerRadius);
        elementData[@"previousConfig"] = [NSData dataWithBytes:(const void *)config length:sizeof(Clay_RectangleRenderData)];
        NSLog(@"view = %@", element);

        Clay_Color bgColor = config->backgroundColor;
        element.backgroundColor = Clay_colorToUIColor(bgColor);
        break;
      }
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_START: { 
        if (scrollData.found) {
          ScrollView *scroll = (ScrollView *)element;
          if ((u64)scroll.contentSize.width != (u64)scrollData.contentDimensions.width || (u64)scroll.contentSize.height != (u64)scrollData.contentDimensions.height) {
            
              [scroll setContentSize:CGSizeMake(scrollData.contentDimensions.width, scrollData.contentDimensions.height)];

              [scroll.contentView setFrame:CGRectMake(0, 0, scrollData.contentDimensions.width, scrollData.contentDimensions.height)];
          }
        }
        ScissorStack_push(&scissorStack, (ScissorItem) {
            .nextAllocation = {bbox.x, bbox.y},
            .element = element,
            .nextElementIndex = 0
        });
        break;
      }
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_END: {
        ScissorStack_pop(&scissorStack);
        break;
      }
      case CLAY_RENDER_COMMAND_TYPE_TEXT: {
        
        Clay_TextRenderData *config = &renderCommand->renderData.text; 
        Clay_StringSlice string = config->stringContents;
        NSData *previousConfig = elementData[@"previousConfig"];

        if (isMemoryEqual((void *)previousConfig.bytes, previousConfig.length, (void *)config, sizeof(Clay_TextRenderData))) {
          break; 
        }
        elementData[@"previousConfig"] = [NSData dataWithBytes:(const void *)config length:sizeof(Clay_TextRenderData)];

        UILabel *textElement = (UILabel *)element;
        textElement.textColor = Clay_colorToUIColor(config->textColor);
        NSString *previousText = elementData[@"previousText"];
        textElement.text = [[NSString alloc] initWithBytes:(void *)string.chars 
                                                      length:string.length 
                                                    encoding:NSUTF8StringEncoding];
        for (u32 i = 0; i < textElement.superview.subviews.count; i++) {
          NSLog(@"sibling = %@", textElement.superview.subviews[i]);
        }
        if ((u64)string.length != (u64)previousText.length || !isMemoryEqual((void *)[previousText cStringUsingEncoding:NSUTF8StringEncoding], previousText.length, (void *)string.chars, string.length)) {
          textElement.text = [[NSString alloc] initWithBytes:(void *)string.chars 
                                                      length:string.length 
                                                    encoding:NSUTF8StringEncoding];
          elementData[@"previousText"] = textElement.text;

        }

        break;
      }
      default: {
        NSLog(@"Not found");
      }
    }
  }
}


Clay_RenderCommandArray IOS_layout(void);


@interface Window : UIWindow
@end

@implementation Window

@end


@interface AppDelegate ()
@end

// This function is new since the video was published
void HandleClayErrors(Clay_ErrorData errorData) {
    printf("%s", errorData.errorText.chars);
}


@interface GestureRecognizer : UIGestureRecognizer
@end

@implementation GestureRecognizer 
- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    UITouch *touch = touches.allObjects[0];
    CGPoint point = [touch locationInView:touch.window];
    tapState.point.x = point.x;
    tapState.point.y = point.y;
    tapState.isPressed = 3;
  }
}

- (void) touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    UITouch *touch = touches.allObjects[0];
    CGPoint point = [touch locationInView:touch.window];
    tapState.point.x = point.x;
    tapState.point.y = point.y;
    tapState.isPressed = 3;
  }
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) { 
    tapState.isPressed = 2;
  }
}

- (void) touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    tapState.isPressed = 2; 
  }
}

@end


@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    CGRect nativeBounds = [[UIScreen mainScreen] nativeBounds];
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat scale = [UIScreen mainScreen].scale;
    self.window = [[Window alloc] initWithFrame:bounds];
    self.window.rootViewController = [[UIViewController alloc] init];
    UIView* view = [[UIView alloc] initWithFrame:bounds];
    self.window.rootViewController.view = view;
    self.window.backgroundColor = [UIColor blueColor];
    
    NSLog(
        @"Main screen origin:\n %@\n %@\n scale %f", 
        NSStringFromCGRect(nativeBounds),
        NSStringFromCGRect([[UIScreen mainScreen] bounds]),
        scale
    );

  
    u64 clayRequiredMemory = Clay_MinMemorySize();
    Clay_Arena clayMemory = Clay_CreateArenaWithCapacityAndMemory(clayRequiredMemory, mmap(nil, clayRequiredMemory, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0));
    Clay_Initialize(clayMemory, (Clay_Dimensions) {
        .width = self.window.frame.size.width,
        .height = self.window.frame.size.height
    }, (Clay_ErrorHandler) { HandleClayErrors, nil });
    Clay_SetMeasureTextFunction(IOS_MeasureText, nil);

    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSRunLoopCommonModes];

    GestureRecognizer *gestureRecognizer = [[GestureRecognizer alloc] init];
    [self.window addGestureRecognizer:gestureRecognizer];

    [self.window makeKeyAndVisible];

    return YES;
}


- (void)step:(CADisplayLink *)sender {
  UIView *view = self.window.rootViewController.view;
  Clay_SetLayoutDimensions((Clay_Dimensions) {
      .width = view.frame.size.width,
      .height = view.frame.size.height
  });

  Clay_RenderCommandArray commands = IOS_layout();
  IOS_Render(commands, self);
}

@end

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

#define max(x, y) (x > y ? x : y)

void HandleRendererButtonInteraction(Clay_ElementId elementId, Clay_PointerData pointerInfo, intptr_t userData) {
  unused(elementId);
  unused(userData);
  if (pointerInfo.state == CLAY_POINTER_DATA_PRESSED_THIS_FRAME || pointerInfo.state == CLAY_POINTER_DATA_PRESSED) {
    appContext.buttonSize = max(200, appContext.buttonSize - 10);
  }
}

#define STRING_SLICE(string, size) (CLAY__INIT(Clay_String) { .isStaticallyAllocated = true, .length = size, .chars = (string) })

// ios-colors
Clay_Color mint  = {0, 200, 179, 255};
Clay_Color black = {0, 0, 0, 255};
Clay_Color gray6 = {28, 28, 30, 255};
Clay_Color red   = {255, 66, 69, 255};
Clay_Color blue  = {0, 145, 255, 255};
Clay_Color green = {48, 209, 88, 255};
Clay_Color yellow = {255, 214, 0, 255};

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
        .padding = {.top = 56 },
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
      /*
      CLAY_TEXT(CLAY_STRING("SOME TEXT"), CLAY_TEXT_CONFIG({
          .fontId = 0,
          .fontSize = 24,
          .textColor = black
      }));
      */

    }
    CLAY({
      .id = CLAY_ID("SCROLL_VIEW"),
      .layout = {
        .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_GROW(0) },
        .layoutDirection = CLAY_TOP_TO_BOTTOM, 
        .childGap = 16
      },
      .clip = {
        .vertical = true
        //.childOffset = Clay_GetScrollOffset()
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

    /*
    RecyclerContext rCtx = BeginRecycler(CLAY_STRING("boxes"), true, 1);
    CLAY({
      .id = rCtx.containerId,
      .layout = {
        .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_GROW(0) },
        .layoutDirection = CLAY_TOP_TO_BOTTOM,
      },
      .backgroundColor = black,
      .clip = { .vertical = true }
    }) {
      RecyclerItem item = recyclerGetNext(&rCtx);
      while (item.valid) {

        CLAY({
          .id = item.id,
          .layout = {
            .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_FIT(0) }
          }
        }) {
          CLAY({
            .id = CLAY_IDI_LOCAL("CELL", item.index),
            .layout = {
              .sizing = { CLAY_SIZING_GROW(0), CLAY_SIZING_FIXED(56) },
              .padding = { .bottom = 8 },
            },
            .backgroundColor = item.index % 2 == 0 ? red : (item.index % 3 ? green : blue)
          })
          {
            CLAY_TEXT(CLAY_STRING("CSTRhh"), CLAY_TEXT_CONFIG({
              .fontId = 1,
              .fontSize = 24,
              .textColor = gray6
            }));

          }
        }
        item = recyclerGetNext(&rCtx);
      }
    }

    */
      
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

int main(int argc, char * argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
}
