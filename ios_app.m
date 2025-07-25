#include <QuartzCore/QuartzCore.h>
#include <Foundation/Foundation.h>
#include <UIKit/UIKit.h>
#include <stdint.h> // stdint's
#include <stdbool.h> // bool
#include <sys/mman.h> // for mmap
#include <assert.h> // for assert
#include <objc/runtime.h>
#include "./u.h"
#include "./pepe_layout.h"
#include "./ios_helpers.h"

@interface ScrollView : UIView
@property (strong, nonatomic) UIView *contentView;
@property (strong, nonatomic) UIScrollView *scroll;
@end

typedef struct TapState TapState;
struct TapState {
  Pepe_Point point;
  i32 isPressed;
};

typedef struct AppContext AppContext;
struct AppContext {
  Pepe_Context context;
  TapState     tapState;
};

static AppContext appContext;

Pepe_Point
queryScrollOffsetFunction(u32 elementId, void *userData)
{
  Pepe_Point result = {0};
  NSDictionary *elementsCache = (__bridge NSDictionary *)userData;
  NSDictionary *elementData = elementsCache[[NSString stringWithFormat:@"%u", elementId]];
  if (elementData) {
     UIView *view = elementData[@"view"];
     if (view && [view isKindOfClass:[ScrollView class]]) {
       result.x = ((ScrollView *)view).scroll.contentOffset.x;
       result.y = ((ScrollView *)view).scroll.contentOffset.y;
     }
  }
  return result;
}


typedef struct ScissorItem ScissorItem;
struct ScissorItem {
  Pepe_Point  nextAllocation;
  UIView      *element;
  i32         nextElementIndex;
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
  size.height *= 3;
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
@property Pepe_Context context;

@property TapState tapState;

@end

static NSData *emptyData;
static NSString *emptyString;

NSMutableDictionary*
makeElementData(UIView *view)
{
  if (emptyData == nil) {
    emptyData = [NSData dataWithBytes:nil length: 0];
  }
  if (emptyString == nil) {
    emptyString = @"";
  }
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
IOS_Render(Pepe_CommandsIterator iterator, AppDelegate *delegate) 
{
  NSMutableDictionary *elementsCache = delegate.elementsCache;
  UIView *root = delegate.window.rootViewController.view;
  PEPE_PROCESS_COMMANDS(iterator, command) {
    NSNumber *key = @((NSUInteger)command.id);

    switch (command.type) {
      case PEPE_RECT: { 
        UIView *view;
        if (!elementsCache[key]) {
          view = [[UIView alloc] initWithFrame:Pepe_RectToCGRect(command.frame)];
          elementsCache[key] = view;
          [root addSubview:view];
        } else {
          view = elementsCache[key];
        }
        view.backgroundColor = Pepe_ColorToUIColor(command.backgroundColor);
        break;
      }
      case PEPE_TEXT: {
        UILabel *view;
        if (!elementsCache[key]) {
          view = [[UILabel alloc] initWithFrame:Pepe_RectToCGRect(command.frame)];
          elementsCache[key] = view;
          [root addSubview:view];
        } else {
          view = elementsCache[key];
        }
        if (command.backgroundColor.a > 0) {
          view.backgroundColor = Pepe_ColorToUIColor(command.backgroundColor);
        }
        view.text = [[NSString alloc] initWithBytes:(void *)command.text.base length:command.text.len encoding:NSUTF8StringEncoding];
        break;
      }
      default:
        printf("not implemented");
    }
  }
  
}

Pepe_CommandsIterator IOS_layout(Pepe_Context *context);


@interface Window : UIWindow
@end

@implementation Window

@end


@interface AppDelegate ()
@end

@interface GestureRecognizer : UIGestureRecognizer
@property (nonatomic) TapState *tapState;

@end

@implementation GestureRecognizer 
- (void) touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    UITouch *touch = touches.allObjects[0];
    CGPoint point = [touch locationInView:touch.window];
    self.tapState->point.x = point.x;
    self.tapState->point.y = point.y;
    self.tapState->isPressed = 3;
  }
}

- (void) touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    UITouch *touch = touches.allObjects[0];
    CGPoint point = [touch locationInView:touch.window];
    self.tapState->point.x = point.x;
    self.tapState->point.y = point.y;
    self.tapState->isPressed = 3;
  }
}

- (void) touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) { 
    self.tapState->isPressed = 2;
  }
}

- (void) touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
  if (touches.count == 1) {
    self.tapState->isPressed = 2; 
  }
}

@end


Pepe_CommandsIterator App_Layout(Pepe_Context *ctx);


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
 
    self.elementsCache = [[NSMutableDictionary alloc] init];
 
    Pepe_Slice memory = Pepe_SliceInit(mmap(nil, REQUERED_MEMORY, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0), REQUERED_MEMORY);
    appContext.context = Pepe_ContextInit(memory);

    CADisplayLink *displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(step:)];
    [displayLink addToRunLoop:[NSRunLoop currentRunLoop]
                      forMode:NSRunLoopCommonModes];

    GestureRecognizer *gestureRecognizer = [[GestureRecognizer alloc] init];
    gestureRecognizer.tapState = &self->_tapState;
    [self.window addGestureRecognizer:gestureRecognizer];

    [self.window makeKeyAndVisible];

    return YES;
}


- (void)step:(CADisplayLink *)sender {
  //UIView *view = self.window.rootViewController.view;

  Pepe_CommandsIterator commands = App_Layout(&appContext.context);
  IOS_Render(commands, self);
}

@end

Pepe_CommandsIterator
App_Layout(Pepe_Context *ctx)
{
  Pepe_BeginLayout(ctx);
  Pepe_PushCommand(ctx, (Pepe_Command) {
    .id = Pepe_Id(ctx, PEPE_STRING_CONST("RECT")),
    .type = PEPE_RECT, 
    .frame = (Pepe_Frame) { .origin = {0, 0}, .size = {100, 100} },
    .backgroundColor = (Pepe_Color) { .r = 255, .g = 255, .b = 255, .a = 255 }
  });
  Pepe_PushCommand(ctx, (Pepe_Command) {
    .id    = Pepe_Id(ctx, PEPE_STRING_CONST("TEXT")),
    .type  = PEPE_TEXT,
    .frame = (Pepe_Frame) { .origin = {0, 100}, .size = {200, 100} },
    .backgroundColor = (Pepe_Color) { .r = 255, .g = 0, .b = 0, .a = 255 },
    .text  = PEPE_STRING_CONST("SOME LABEL TEXT")
  });

  return Pepe_EndLayout(ctx);
}


int main(int argc, char * argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
  }
}
