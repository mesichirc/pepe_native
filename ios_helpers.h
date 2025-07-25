#ifndef IOS_HELPERS
#define IOS_HELPERS

static inline UIColor *
Pepe_ColorToUIColor(Pepe_Color color)
{
  return [UIColor colorWithRed:((f32)color.r / 255.0f) 
                         green:((f32)color.g / 255.0f)
                          blue:((f32)color.b / 255.0f) 
                         alpha:((f32)color.a / 255.0f)];
}

static inline CGRect
Pepe_RectToCGRect(Pepe_Frame rect) {
  CGRect cgframe = {0};

  cgframe.origin.x    = rect.origin.x;
  cgframe.origin.y    = rect.origin.y;
  cgframe.size.width  = rect.size.width;
  cgframe.size.height = rect.size.height;

  return cgframe;
}

void
UIView_setBorderRadius(UIView *view, Pepe_CornerRadius corners) {
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
Pepe_Size 
IOS_MeasureText(Pepe_String text, Pepe_TextElementConfig *config, void *ud)
{
  unused(config);
  unused(ud);
  Pepe_Size textSize = { 0 };
  UIFont *font = [UIFont systemFontOfSize:config->fontSize];
  // TODO: remove allocation
  NSDictionary *attrs = @{
    NSFontAttributeName : font
  };
  
  NSString *str = [[NSString alloc] initWithBytesNoCopy:(void *)text.base length:text.len encoding:NSUTF8StringEncoding freeWhenDone:NO];

  // TODO: remove allocation try to reuse attrstr, LRU ?;
  NSAttributedString *attrstr = [[NSAttributedString alloc] initWithString:str attributes:attrs];

  CGSize size = [attrstr size];

  textSize.width = size.width;
  textSize.height = size.height;

  return textSize;
}

#endif
