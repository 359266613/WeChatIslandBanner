#import "WeChatMessageMergeSettingsController.h"
#import "WMMConfig.h"

typedef NS_ENUM(NSInteger, WMMSection) {
    WMMSectionMain = 0,
    WMMSectionSpacing,
    WMMSectionAvatar,
    WMMSectionAdvanced,
    WMMSectionCount
};

@interface WeChatMessageMergeSettingsController ()
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UISwitch *hideLeftSwitch;
@property (nonatomic, strong) UISwitch *hideRightSwitch;
@property (nonatomic, strong) UISwitch *customLogicSwitch;
@property (nonatomic, strong) WMMConfig *config;
@property (nonatomic, strong) NSArray<NSNumber *> *spacingValues;
@property (nonatomic, strong) NSArray<NSNumber *> *timeWindowValues;
@property (nonatomic, strong) NSArray<NSString *> *timeWindowTitles;
@end

@implementation WeChatMessageMergeSettingsController

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleInsetGrouped];
    if (self) {
        self.title = @"消息合并";
        _config = [WMMConfig shared];
        _spacingValues = @[@0.5, @1.0, @2.0, @4.0, @8.0];
        _timeWindowValues = @[@30, @60, @120, @300, @600];
        _timeWindowTitles = @[@"30秒", @"1分钟", @"2分钟", @"5分钟", @"10分钟"];
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
    self.enableSwitch.on = self.config.enableMerge;
    [self.enableSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.hideLeftSwitch = [[UISwitch alloc] init];
    self.hideLeftSwitch.on = self.config.hideLeftAvatar;
    [self.hideLeftSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.hideRightSwitch = [[UISwitch alloc] init];
    self.hideRightSwitch.on = self.config.hideRightAvatar;
    [self.hideRightSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];

    self.customLogicSwitch = [[UISwitch alloc] init];
    self.customLogicSwitch.on = self.config.enableCustomMergeLogic;
    [self.customLogicSwitch addTarget:self action:@selector(onSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Actions

- (void)onSwitchChanged:(UISwitch *)sender {
    self.config.enableMerge = self.enableSwitch.on;
    self.config.hideLeftAvatar = self.hideLeftSwitch.on;
    self.config.hideRightAvatar = self.hideRightSwitch.on;
    self.config.enableCustomMergeLogic = self.customLogicSwitch.on;
    [self.config save];
}

- (void)resetTapped {
    [self.config resetToDefaults];
    [self buildControls];
    [self.config save];
    [self.tableView reloadData];
}

#pragma mark - Table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return WMMSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case WMMSectionMain: return 1;
        case WMMSectionSpacing: return 2;
        case WMMSectionAvatar: return 2;
        case WMMSectionAdvanced: return 2;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case WMMSectionMain: return @"基础设置";
        case WMMSectionSpacing: return @"消息间距";
        case WMMSectionAvatar: return @"头像显示";
        case WMMSectionAdvanced: return @"高级设置";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case WMMSectionMain: return @"启用后，连续消息将自动合并显示";
        case WMMSectionAdvanced: return @"自定义合并逻辑可根据时间窗口智能合并消息";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    
    switch (indexPath.section) {
        case WMMSectionMain: {
            cell.textLabel.text = @"启用消息合并";
            cell.accessoryView = self.enableSwitch;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } break;
            
        case WMMSectionSpacing: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"群聊间距";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", self.config.groupSpacing];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            } else {
                cell.textLabel.text = @"私聊间距";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f", self.config.privateSpacing];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        } break;
            
        case WMMSectionAvatar: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"隐藏左边头像";
                cell.accessoryView = self.hideLeftSwitch;
            } else {
                cell.textLabel.text = @"隐藏右边头像";
                cell.accessoryView = self.hideRightSwitch;
            }
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } break;
            
        case WMMSectionAdvanced: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"启用自定义合并逻辑";
                cell.accessoryView = self.customLogicSwitch;
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            } else {
                cell.textLabel.text = @"合并时间窗口";
                NSInteger idx = [self.timeWindowValues indexOfObject:@(self.config.mergeTimeWindow)];
                if (idx != NSNotFound) {
                    cell.detailTextLabel.text = self.timeWindowTitles[idx];
                } else {
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld秒", (long)self.config.mergeTimeWindow];
                }
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            }
        } break;
            
        default: break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == WMMSectionSpacing) {
        [self showSpacingPickerForRow:indexPath.row];
    } else if (indexPath.section == WMMSectionAdvanced && indexPath.row == 1) {
        [self showTimeWindowPicker];
    }
}

- (void)showSpacingPickerForRow:(NSInteger)row {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:row == 0 ? @"群聊间距" : @"私聊间距"
                                                                   message:@"选择消息间距"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSNumber *value in self.spacingValues) {
        NSString *title = [NSString stringWithFormat:@"%.1f", value.doubleValue];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (row == 0) {
                self.config.groupSpacing = value.doubleValue;
            } else {
                self.config.privateSpacing = value.doubleValue;
            }
            [self.config save];
            [self.tableView reloadData];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showTimeWindowPicker {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"合并时间窗口"
                                                                   message:@"选择时间窗口"
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSInteger i = 0; i < self.timeWindowValues.count; i++) {
        NSNumber *value = self.timeWindowValues[i];
        NSString *title = self.timeWindowTitles[i];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.config.mergeTimeWindow = value.integerValue;
            [self.config save];
            [self.tableView reloadData];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
