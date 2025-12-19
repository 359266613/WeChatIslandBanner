#import "WeChatIslandBannerSettingsController.h"
#import "WIBConfig.h"

typedef NS_ENUM(NSInteger, WIBSection) {
    WIBSectionMain = 0,
    WIBSectionBackground,
    WIBSectionBorder,
    WIBSectionText,
    WIBSectionCount
};

@interface WeChatIslandBannerSettingsController () <UIColorPickerViewControllerDelegate, UITextFieldDelegate>
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UITextField *widthField;
@property (nonatomic, strong) UITextField *heightField;
@property (nonatomic, strong) UISwitch *bgSwitch;
@property (nonatomic, strong) UISwitch *borderSwitch;
@property (nonatomic, strong) UISwitch *textSwitch;
@property (nonatomic, strong) UIButton *bgColorButton;
@property (nonatomic, strong) UIButton *borderColorButton;
@property (nonatomic, strong) UIButton *textColorButton;
@property (nonatomic, strong) WIBConfig *config;
@property (nonatomic, weak) UIButton *colorPickingButton;
@end

@implementation WeChatIslandBannerSettingsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"灵动岛通知";
        _config = [WIBConfig shared];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"重置"
                                                                              style:UIBarButtonItemStylePlain
                                                                             target:self
                                                                             action:@selector(resetTapped)];
    [self buildControls];
}

- (void)buildControls {
    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.on = self.config.enableIsland;
    [self.enableSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.widthField = [self numericFieldWithValue:self.config.widthRatio placeholder:@"0.50-1.00"];
    self.heightField = [self numericFieldWithValue:self.config.height placeholder:@"36-88"];

    self.bgSwitch = [[UISwitch alloc] init];
    self.bgSwitch.on = self.config.enableBackground;
    [self.bgSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.borderSwitch = [[UISwitch alloc] init];
    self.borderSwitch.on = self.config.enableBorder;
    [self.borderSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.textSwitch = [[UISwitch alloc] init];
    self.textSwitch.on = self.config.enableTextColor;
    [self.textSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.bgColorButton = [self colorButtonWithColor:self.config.backgroundColor action:@selector(colorButtonTapped:)];
    self.borderColorButton = [self colorButtonWithColor:self.config.borderColor action:@selector(colorButtonTapped:)];
    self.textColorButton = [self colorButtonWithColor:self.config.textColor action:@selector(colorButtonTapped:)];
}

- (UIButton *)colorButtonWithColor:(UIColor *)color action:(SEL)sel {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, 36, 36);
    btn.layer.cornerRadius = 18;
    btn.layer.borderWidth = 1;
    btn.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.2].CGColor;
    btn.clipsToBounds = YES;
    btn.backgroundColor = color ?: [UIColor whiteColor];
    [btn addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (UITextField *)numericFieldWithValue:(CGFloat)value placeholder:(NSString *)placeholder {
    UITextField *field = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 96, 32)];
    field.borderStyle = UITextBorderStyleRoundedRect;
    field.keyboardType = UIKeyboardTypeDecimalPad;
    field.textAlignment = NSTextAlignmentRight;
    field.placeholder = placeholder;
    field.delegate = self;
    field.text = [NSString stringWithFormat:@"%.2f", value];
    return field;
}

#pragma mark - Actions

- (void)onSwitchChanged:(UISwitch *)sender {
    self.config.enableIsland = self.enableSwitch.on;
    self.config.enableBackground = self.bgSwitch.on;
    self.config.enableBorder = self.borderSwitch.on;
    self.config.enableTextColor = self.textSwitch.on;
    [self.config save];
}

#pragma mark - UITextFieldDelegate

- (void)textFieldDidEndEditing:(UITextField *)textField {
    double val = [textField.text doubleValue];
    if (textField == self.widthField) {
        CGFloat screenWidth = [UIScreen mainScreen].bounds.size.width;
        if (val > 10.0) {
            // 视为像素宽度
            val = MIN(MAX(val, 200.0), screenWidth - 20.0);
            self.config.widthRatio = val / screenWidth;
        } else {
            // 视为比例
            val = MIN(MAX(val, 0.5), 1.0);
            self.config.widthRatio = val;
            val = self.config.widthRatio * screenWidth;
        }
        textField.text = [NSString stringWithFormat:@"%.0f", val];
    } else if (textField == self.heightField) {
        val = MIN(MAX(val, 36.0), 88.0);
        self.config.height = val;
        textField.text = [NSString stringWithFormat:@"%.0f", val];
    }
    [self.config save];
    [self.tableView reloadData];
}

- (void)colorButtonTapped:(UIButton *)sender {
    self.colorPickingButton = sender;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.delegate = self;
    picker.supportsAlpha = YES;
    picker.selectedColor = sender.backgroundColor ?: [UIColor whiteColor];
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)resetTapped {
    [self.config resetToDefaults];
    [self buildControls];
    [self.config save];
    [self.tableView reloadData];
}

#pragma mark - UIColorPickerViewControllerDelegate

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    [self updateColorFromPicker:viewController];
}

- (void)colorPickerViewControllerDidSelectColor:(UIColorPickerViewController *)viewController {
    [self updateColorFromPicker:viewController];
}

- (void)updateColorFromPicker:(UIColorPickerViewController *)picker {
    UIColor *color = picker.selectedColor ?: [UIColor whiteColor];
    if (self.colorPickingButton == self.bgColorButton) {
        self.config.backgroundColor = color;
        self.bgColorButton.backgroundColor = color;
    } else if (self.colorPickingButton == self.borderColorButton) {
        self.config.borderColor = color;
        self.borderColorButton.backgroundColor = color;
    } else if (self.colorPickingButton == self.textColorButton) {
        self.config.textColor = color;
        self.textColorButton.backgroundColor = color;
    }
    [self.config save];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WIBSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case WIBSectionMain: return 3; // 启用 + 宽度 + 高度
        case WIBSectionBackground: return 2; // 开关 + 颜色
        case WIBSectionBorder: return 2; // 开关 + 颜色
        case WIBSectionText: return 2; // 开关 + 颜色
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case WIBSectionMain: return @"基础";
        case WIBSectionBackground: return @"背景";
        case WIBSectionBorder: return @"边框";
        case WIBSectionText: return @"文字";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    switch (indexPath.section) {
        case WIBSectionMain: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"启用灵动岛";
                cell.accessoryView = self.enableSwitch;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"宽度";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f%%", self.config.widthRatio * 100];
                cell.accessoryView = self.widthField;
            } else {
                cell.textLabel.text = @"高度";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.0f pt", self.config.height];
                cell.accessoryView = self.heightField;
            }
        } break;
        case WIBSectionBackground: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"启用背景";
                cell.accessoryView = self.bgSwitch;
            } else {
                cell.textLabel.text = @"背景颜色";
                cell.accessoryView = self.bgColorButton;
            }
        } break;
        case WIBSectionBorder: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"启用边框";
                cell.accessoryView = self.borderSwitch;
            } else {
                cell.textLabel.text = @"边框颜色";
                cell.accessoryView = self.borderColorButton;
            }
        } break;
        case WIBSectionText: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"启用文字颜色";
                cell.accessoryView = self.textSwitch;
            } else {
                cell.textLabel.text = @"文字颜色";
                cell.accessoryView = self.textColorButton;
            }
        } break;
        default: break;
    }
    return cell;
}

@end
