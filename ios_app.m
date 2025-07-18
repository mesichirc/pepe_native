#include <QuartzCore/QuartzCore.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#define CLAY_IMPLEMENTATION
#include "./clay.h"
#include <stdint.h> // stdint's
#include <stdbool.h> // bool
#include <sys/mman.h> // for mmap
#include <assert.h> // for assert
#include <objc/runtime.h>
#include "./u.h"
#include "./app_example.h"

@interface ScrollView : UIView
@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIScrollView *scroll;
@end

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
  if (corners.topLeft == 0 && corners.bottomLeft == 0 && corners.topRight == 0 && corners.bottomRight == 0) {
    return;
  }
  if (corners.topLeft == corners.bottomRight && corners.topRight == corners.bottomLeft && corners.bottomLeft == corners.topLeft) {
    view.layer.cornerRadius = corners.bottomRight; 
    view.clipsToBounds = true;
    return;
  }
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


@implementation ScrollView
@end

ScrollView *
ScrollView_init(CGRect frame)
{
  ScrollView *scrollView = [[ScrollView alloc] initWithFrame:frame];
  scrollView.scroll = [[UIScrollView alloc] initWithFrame:scrollView.bounds];
  scrollView.contentView = [[UIView alloc] initWithFrame:scrollView.scroll.bounds];

  [scrollView addSubview:scrollView.scroll];
  [scrollView.scroll addSubview:scrollView.contentView];

  return scrollView;
}

void
ScrollView_setFrame(ScrollView *view, CGRect frame)
{
  view.frame = frame;
  view.scroll.frame = frame;
}

CGSize
ScrollView_getContentSize(ScrollView *view)
{
  return view.scroll.contentSize;
}

void
ScrollView_setContentSize(ScrollView *view, CGSize size)
{
  view.scroll.contentSize = size;
  CGRect frame = view.contentView.frame;
  view.contentView.frame = CGRectMake(
      frame.origin.x,
      frame.origin.y,
      size.width,
      size.height
  );
}


#define CONTENT_VIEW(view) ([(view) isKindOfClass:[ScrollView class]] ? ((ScrollView *)view).contentView : view)

#define SUBVIEWS(view) ([(view) isKindOfClass:[ScrollView class]] ? ((ScrollView *)view).contentView.subviews : view.subviews)

void
View_addSubview(UIView *view, UIView *child)
{
  [CONTENT_VIEW(view) addSubview:child];
}

void
View_insertSubview(UIView *view, UIView *child, u32 index)
{
  [CONTENT_VIEW(view) insertSubview:child atIndex:index];
}

void 
View_inserSubviewAbove(UIView *view, UIView *child, UIView *above)
{
  [CONTENT_VIEW(view) insertSubview:child aboveSubview:above];
}

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
    NSString *key                     = [NSString stringWithFormat:@"%u", renderCommand->id];
    bool isMultiConfigElement = previousId == renderCommand->id;
    Clay_ScrollContainerData scrollData = Clay_GetScrollContainerDataByIntID(renderCommand->id);   
    if (!delegate.elementsCache[key]) {

      // TODO: figure out scroll view and recycler view
      switch (renderCommand->commandType)
      {
        case CLAY_RENDER_COMMAND_TYPE_RECTANGLE: {
          if (scrollData.found) {
            ScrollView *scrollView = ScrollView_init(frame);
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
    NSArray *parentSubviews = SUBVIEWS(parentElement);
    if (!isMultiConfigElement && (parentSubviews.count == 0 || ((u64)[parentSubviews indexOfObject:element] != (u64)parentElementData->nextElementIndex)) && element) {
      if (parentElementData->nextElementIndex == 0) {
        if (parentSubviews.count == 0) {
          View_insertSubview(parentElement, element, 0);
        } else {
          View_addSubview(parentElement, element);
        }
      } else {
        [element removeFromSuperview]; 
        View_inserSubviewAbove(parentElement, element, parentSubviews[(u64)(parentElementData->nextElementIndex - 1)]);
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
        Clay_Color bgColor = config->backgroundColor;
        element.backgroundColor = Clay_colorToUIColor(bgColor);
        break;
      }
      case CLAY_RENDER_COMMAND_TYPE_SCISSOR_START: { 

        if (scrollData.found && [element isKindOfClass:[ScrollView class]]) {
          ScrollView *scrollView = (ScrollView *)element;
          CGSize contentSize = ScrollView_getContentSize(scrollView);
          if ((u64)contentSize.width != (u64)scrollData.contentDimensions.width || (u64)contentSize.height != (u64)scrollData.contentDimensions.height) { 
            ScrollView_setContentSize(scrollView, CGSizeMake(
              scrollData.contentDimensions.width,
              scrollData.contentDimensions.height
            ));
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
    printf("%s\n", errorData.errorText.chars);
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


int main(int argc, char * argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
}
