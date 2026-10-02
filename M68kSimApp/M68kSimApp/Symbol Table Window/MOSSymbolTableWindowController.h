//
//  MOSSymbolTableWindowController.h
//  Tricky68k
//

#import <Cocoa/Cocoa.h>


@interface MOSSymbolTableWindowController : NSWindowController
    <NSTableViewDataSource, NSTableViewDelegate>

- (void)setSymbolTable:(NSDictionary *)symbolTable;

@end
