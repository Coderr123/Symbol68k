//
//  MOSSymbolTableWindowController.m
//  Tricky68k
//

#import "MOSSymbolTableWindowController.h"


static NSString * const MOSSymbolNameColumnIdentifier = @"symbol";
static NSString * const MOSSymbolAddressColumnIdentifier = @"address";
static NSString * const MOSSymbolDecimalColumnIdentifier = @"decimal";


@implementation MOSSymbolTableWindowController {
  NSDictionary *_symbolTable;
  NSArray *_symbols;
  NSArray *_filteredSymbols;
  NSTableView *_tableView;
  NSSearchField *_searchField;
  NSTextField *_summaryLabel;
}


- (instancetype)init
{
  NSRect contentRect = NSMakeRect(0, 0, 520, 430);
  NSUInteger style = NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
    NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable;
  NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
    styleMask:style backing:NSBackingStoreBuffered defer:NO];

  self = [super initWithWindow:window];
  if (self) {
    [window setTitle:NSLocalizedString(@"Symbol Table", @"Symbol table window title")];
    [window setReleasedWhenClosed:NO];
    [window setFrameAutosaveName:@"MOSSymbolTableWindow"];
    [window setMinSize:NSMakeSize(360, 240)];
    [self buildInterface];
    [self setSymbolTable:@{}];
  }
  return self;
}


- (void)buildInterface
{
  NSView *contentView = [[self window] contentView];

  _searchField = [[NSSearchField alloc] initWithFrame:NSZeroRect];
  [_searchField setPlaceholderString:NSLocalizedString(@"Filter symbols or addresses",
    @"Symbol table search placeholder")];
  [_searchField setTarget:self];
  [_searchField setAction:@selector(filterSymbols:)];
  [_searchField setContinuous:YES];
  [_searchField setTranslatesAutoresizingMaskIntoConstraints:NO];
  [contentView addSubview:_searchField];

  _summaryLabel = [[NSTextField alloc] initWithFrame:NSZeroRect];
  [_summaryLabel setBezeled:NO];
  [_summaryLabel setBordered:NO];
  [_summaryLabel setDrawsBackground:NO];
  [_summaryLabel setEditable:NO];
  [_summaryLabel setSelectable:NO];
  [_summaryLabel setTextColor:[NSColor secondaryLabelColor]];
  [_summaryLabel setTranslatesAutoresizingMaskIntoConstraints:NO];
  [contentView addSubview:_summaryLabel];

  _tableView = [[NSTableView alloc] initWithFrame:NSZeroRect];
  [_tableView setDataSource:self];
  [_tableView setDelegate:self];
  [_tableView setUsesAlternatingRowBackgroundColors:YES];
  [_tableView setAllowsMultipleSelection:YES];
  [_tableView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];

  NSTableColumn *symbolColumn = [[NSTableColumn alloc]
    initWithIdentifier:MOSSymbolNameColumnIdentifier];
  [[symbolColumn headerCell] setStringValue:NSLocalizedString(@"Symbol",
    @"Symbol table column heading")];
  [symbolColumn setWidth:240];
  [symbolColumn setMinWidth:120];
  [symbolColumn setSortDescriptorPrototype:[NSSortDescriptor
    sortDescriptorWithKey:@"value" ascending:YES
    selector:@selector(localizedStandardCompare:)]];
  [_tableView addTableColumn:symbolColumn];

  NSTableColumn *addressColumn = [[NSTableColumn alloc]
    initWithIdentifier:MOSSymbolAddressColumnIdentifier];
  [[addressColumn headerCell] setStringValue:NSLocalizedString(@"Address",
    @"Symbol table column heading")];
  [addressColumn setWidth:110];
  [addressColumn setMinWidth:90];
  [addressColumn setSortDescriptorPrototype:[NSSortDescriptor
    sortDescriptorWithKey:@"key" ascending:YES]];
  [_tableView addTableColumn:addressColumn];

  NSTableColumn *decimalColumn = [[NSTableColumn alloc]
    initWithIdentifier:MOSSymbolDecimalColumnIdentifier];
  [[decimalColumn headerCell] setStringValue:NSLocalizedString(@"Decimal",
    @"Symbol table column heading")];
  [decimalColumn setWidth:110];
  [decimalColumn setMinWidth:80];
  [decimalColumn setSortDescriptorPrototype:[NSSortDescriptor
    sortDescriptorWithKey:@"key" ascending:YES]];
  [_tableView addTableColumn:decimalColumn];

  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
  [scrollView setDocumentView:_tableView];
  [scrollView setHasVerticalScroller:YES];
  [scrollView setHasHorizontalScroller:YES];
  [scrollView setBorderType:NSBezelBorder];
  [scrollView setAutohidesScrollers:YES];
  [scrollView setTranslatesAutoresizingMaskIntoConstraints:NO];
  [contentView addSubview:scrollView];

  NSDictionary *views = NSDictionaryOfVariableBindings(_searchField, _summaryLabel, scrollView);
  [contentView addConstraints:[NSLayoutConstraint
    constraintsWithVisualFormat:@"H:|-12-[_searchField]-12-|"
    options:0 metrics:nil views:views]];
  [contentView addConstraints:[NSLayoutConstraint
    constraintsWithVisualFormat:@"H:|-12-[_summaryLabel]-12-|"
    options:0 metrics:nil views:views]];
  [contentView addConstraints:[NSLayoutConstraint
    constraintsWithVisualFormat:@"H:|[scrollView]|"
    options:0 metrics:nil views:views]];
  [contentView addConstraints:[NSLayoutConstraint
    constraintsWithVisualFormat:@"V:|-12-[_searchField]-6-[_summaryLabel]-8-[scrollView]|"
    options:0 metrics:nil views:views]];
}


- (void)setSymbolTable:(NSDictionary *)symbolTable
{
  _symbolTable = [symbolTable copy] ?: @{};
  [self updateFilteredSymbols];
}


- (void)updateFilteredSymbols
{
  NSMutableArray *entries = [[NSMutableArray alloc] init];
  [_symbolTable enumerateKeysAndObjectsUsingBlock:^(id address, id symbol, BOOL *stop) {
    (void)stop;
    if (![address isKindOfClass:[NSNumber class]] ||
        ![symbol isKindOfClass:[NSString class]])
      return;
    [entries addObject:@{@"key": address, @"value": symbol}];
  }];

  NSArray *sortDescriptors = [_tableView sortDescriptors];
  if (![sortDescriptors count])
    sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"key" ascending:YES]];
  _symbols = [entries sortedArrayUsingDescriptors:sortDescriptors];

  NSString *query = [_searchField stringValue];
  if ([query length]) {
    _filteredSymbols = [_symbols filteredArrayUsingPredicate:
      [NSPredicate predicateWithBlock:^BOOL(NSDictionary *entry, NSDictionary *bindings) {
        (void)bindings;
        NSString *symbol = entry[@"value"];
        NSNumber *address = entry[@"key"];
        NSString *hexAddress = [NSString stringWithFormat:@"0x%08X",
          [address unsignedIntValue]];
        NSString *decimalAddress = [address stringValue];
        return [symbol rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
          [hexAddress rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound ||
          [decimalAddress rangeOfString:query options:NSCaseInsensitiveSearch].location != NSNotFound;
      }]];
  } else {
    _filteredSymbols = _symbols;
  }

  NSString *summary;
  if (![_symbols count]) {
    summary = NSLocalizedString(@"No symbols are available for this executable.",
      @"Empty symbol table message");
  } else if ([_filteredSymbols count] == [_symbols count]) {
    summary = [NSString stringWithFormat:NSLocalizedString(@"%lu symbols",
      @"Symbol table item count"), (unsigned long)[_symbols count]];
  } else {
    summary = [NSString stringWithFormat:NSLocalizedString(@"%lu of %lu symbols",
      @"Filtered symbol table item count"), (unsigned long)[_filteredSymbols count],
      (unsigned long)[_symbols count]];
  }
  [_summaryLabel setStringValue:summary];
  [_tableView reloadData];
}


- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
  return [_filteredSymbols count];
}


- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row
{
  NSString *identifier = [tableColumn identifier];
  NSTableCellView *cell = [tableView makeViewWithIdentifier:identifier owner:self];
  if (!cell) {
    cell = [[NSTableCellView alloc] initWithFrame:NSZeroRect];
    [cell setIdentifier:identifier];

    NSTextField *textField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    [textField setBezeled:NO];
    [textField setBordered:NO];
    [textField setDrawsBackground:NO];
    [textField setEditable:NO];
    [textField setSelectable:NO];
    [textField setLineBreakMode:NSLineBreakByTruncatingTail];
    [textField setTranslatesAutoresizingMaskIntoConstraints:NO];
    [cell addSubview:textField];
    [cell setTextField:textField];
    [cell addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-4-[textField]-4-|"
      options:0 metrics:nil views:NSDictionaryOfVariableBindings(textField)]];
    [cell addConstraint:[NSLayoutConstraint constraintWithItem:textField
      attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual
      toItem:cell attribute:NSLayoutAttributeCenterY multiplier:1 constant:0]];
  }

  NSDictionary *entry = _filteredSymbols[row];
  NSNumber *address = entry[@"key"];
  NSString *value;
  if ([identifier isEqualToString:MOSSymbolNameColumnIdentifier]) {
    value = entry[@"value"];
    [[cell textField] setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
  } else if ([identifier isEqualToString:MOSSymbolAddressColumnIdentifier]) {
    value = [NSString stringWithFormat:@"0x%08X", [address unsignedIntValue]];
    [[cell textField] setFont:[NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]]];
  } else {
    value = [address stringValue];
    [[cell textField] setFont:[NSFont userFixedPitchFontOfSize:[NSFont systemFontSize]]];
  }
  [[cell textField] setStringValue:value];
  return cell;
}


- (void)tableView:(NSTableView *)tableView
  sortDescriptorsDidChange:(NSArray *)oldDescriptors
{
  [self updateFilteredSymbols];
}


- (IBAction)filterSymbols:(id)sender
{
  [self updateFilteredSymbols];
}


@end
