# Choujiang Plugin Validation Demo

This demonstrates the parameter validation functionality added to the discourse-choujiang plugin.

## Example Usage

### Valid Lottery Post
```
抽奖名称：2025年春节抽奖活动
奖品：iPhone 15 Pro 一台  
获奖人数：3
开奖时间：2025-12-31 23:59
其他说明：每人仅限参与一次
```

**Validation Result:** ✅ PASS

### Invalid Lottery Posts

#### Missing Required Fields
```
抽奖名称：
奖品：
获奖人数：0
开奖时间：
```

**Validation Result:** ❌ FAIL
- 抽奖名称不能为空
- 奖品不能为空  
- 获奖人数不能为空或为0
- 开奖时间不能为空

#### Invalid Formats
```
抽奖名称：测试抽奖
奖品：测试奖品
获奖人数：-5
开奖时间：2020-01-01 00:00
```

**Validation Result:** ❌ FAIL
- 获奖人数必须是正整数
- 开奖时间必须是未来的时间

## Features Implemented

1. **ActiveRecord Model Validations** - Added comprehensive validations to ChoujiangRecord model
2. **Service Layer Validation** - Created LotteryValidator class for reusable validation logic
3. **Real-time Validation** - Integrated validation into existing post parsing workflow
4. **Friendly Error Messages** - All error messages are in Chinese and user-friendly
5. **Backend Security** - All validation happens on the server side for security
6. **Format Validation** - Validates data types, ranges, and business rules

## Integration Points

- **Model Layer**: ChoujiangRecord and ChoujiangParticipant models with ActiveRecord validations
- **Service Layer**: LotteryValidator class for complex validation logic
- **Parsing Integration**: Enhanced parse_choujiang_info with validation
- **Scheduled Job**: AutoChoujiangDraw now validates before processing
- **Hook System**: validate_lottery_post method for integration with Discourse post events

All validations ensure that lottery posts meet the required format and business rules before being processed by the system.