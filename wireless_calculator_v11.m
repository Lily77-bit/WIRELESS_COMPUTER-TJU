% 无线计算器 V32 - 增加误码率测试功能

function wireless_calculator_v32()
    fig = uifigure('Name', '天津大学无线计算器', 'Position', [100 100 600 800]);
    
    global calculation sampling_freq;
    global recObj audioData;
    global freq_0 freq_1 bit_duration;
    global encoding_map decoding_map;
    global isListening isSender isStrongListen;
    global lastResult lastExpr lastSentCode lastSentIsResult;
    global retryCount maxRetry;
    global noisePlayer isPlayingNoise;
    global batchExprs batchResults;
    global isTesting;
    
    calculation = '';
    sampling_freq = 44100;
    recObj = [];
    audioData = [];
    isListening = false;
    isSender = true;
    isStrongListen = false;
    lastResult = 0;
    lastExpr = '';
    lastSentCode = '';
    lastSentIsResult = false;
    retryCount = 0;
    maxRetry = 3;
    noisePlayer = [];
    isPlayingNoise = false;
    batchExprs = {};
    batchResults = [];
    isTesting = false;
    
    freq_0 = 1000;
    freq_1 = 2000;
    bit_duration = 0.1;
    
    chars = {'0','1','2','3','4','5','6','7','8','9','+','-','*','/','(',')','.',';'};
    codes = {'00000','00001','00010','00011','00100','00101','00110','00111',... 
             '01000','01001','01010','01011','01100','01101','01110','01111','10000','10001'};
    encoding_map = containers.Map(chars, codes);
    decoding_map = containers.Map(codes, chars);
    
    % 标题
    uilabel(fig, 'Position', [20 760 560 30], 'Text', '天津大学无线计算器',...
        'FontSize', 20, 'FontWeight', 'bold', 'HorizontalAlignment', 'center',...
        'FontColor', [0.1 0.3 0.6]);
    uilabel(fig, 'Position', [20 735 560 20], 'Text', 'Designed by Lily & Onlyone',...
        'FontSize', 12, 'FontAngle', 'italic', 'HorizontalAlignment', 'center',...
        'FontColor', [0.5 0.5 0.5]);
    
    % 身份选择
    panelRole = uipanel(fig, 'Title', '身份选择', 'Position', [20 660 560 65]);
    roleGroup = uibuttongroup(panelRole, 'Position', [10 5 200 45], 'BorderType', 'none');
    senderRadio = uiradiobutton(roleGroup, 'Position', [10 15 100 22], 'Text', '发信者', 'Value', true);
    receiverRadio = uiradiobutton(roleGroup, 'Position', [100 15 100 22], 'Text', '接收者');
    roleLabel = uilabel(panelRole, 'Position', [220 20 120 22], 'Text', '当前:  发信者',...
        'FontWeight', 'bold', 'FontColor', [0 0.5 0], 'FontSize', 13);
    strongListenCheck = uicheckbox(panelRole, 'Position', [350 20 80 22], 'Text', '强监听',...
        'Value', false, 'FontColor', [0.8 0 0]);
    batchCheck = uicheckbox(panelRole, 'Position', [440 20 80 22], 'Text', '批量模式',...
        'Value', false, 'FontColor', [0 0 0.8]);
    
    % 输入
    panelInput = uipanel(fig, 'Title', '输入 (批量用;分隔)', 'Position', [20 595 560 60]);
    inputEdit = uitextarea(panelInput, 'Position', [10 5 540 30]);
    
    % 配置
    panelConfig = uipanel(fig, 'Title', '配置', 'Position', [20 530 560 60]);
    uilabel(panelConfig, 'Position', [10 20 50 22], 'Text', 'bit(ms):');
    bitEdit = uieditfield(panelConfig, 'numeric', 'Position', [60 20 40 22], 'Value', 100);
    uilabel(panelConfig, 'Position', [110 20 50 22], 'Text', '超时(s):');
    timeoutEdit = uieditfield(panelConfig, 'numeric', 'Position', [160 20 40 22], 'Value', 10);
    uilabel(panelConfig, 'Position', [220 20 200 22], 'Text', '1kHz=0, 2kHz=1', 'FontSize', 10);
    
    % 白噪声和误码率测试
    panelTest = uipanel(fig, 'Title', '测试功能', 'Position', [20 440 560 85]);
    uilabel(panelTest, 'Position', [10 45 50 22], 'Text', '噪声: ');
    noiseVolumeSlider = uislider(panelTest, 'Position', [60 55 120 3], 'Limits', [0 1], 'Value', 0.3);
    noiseVolumeLabel = uilabel(panelTest, 'Position', [185 45 40 22], 'Text', '30%');
    noiseBtn = uibutton(panelTest, 'Position', [230 40 80 30], 'Text', '播放噪声',...
        'BackgroundColor', [0.9 0.7 0.7]);
    noiseStopBtn = uibutton(panelTest, 'Position', [315 40 80 30], 'Text', '停止噪声',...
        'BackgroundColor', [0.7 0.9 0.7]);
    
    uilabel(panelTest, 'Position', [10 10 50 22], 'Text', '次数:');
    testCountEdit = uieditfield(panelTest, 'numeric', 'Position', [60 10 40 22], 'Value', 20);
    uilabel(panelTest, 'Position', [110 10 50 22], 'Text', '算式数:');
    exprCountEdit = uieditfield(panelTest, 'numeric', 'Position', [160 10 40 22], 'Value', 5);
    berTestBtn = uibutton(panelTest, 'Position', [230 5 100 30], 'Text', '误码率测试',...
        'BackgroundColor', [1 0.9 0.6], 'FontWeight', 'bold');
    stopTestBtn = uibutton(panelTest, 'Position', [335 5 80 30], 'Text', '停止测试',...
        'BackgroundColor', [1 0.6 0.6]);
    berLabel = uilabel(panelTest, 'Position', [420 10 130 22], 'Text', 'BER:  -',...
        'FontWeight', 'bold', 'FontSize', 12, 'FontColor', [0 0 0.8]);
    
    % 日志
    uilabel(fig, 'Position', [20 410 100 22], 'Text', '日志:');
    logEdit = uitextarea(fig, 'Position', [20 130 560 280], 'Editable', 'off');
    
    % 状态
    panel1 = uipanel(fig, 'Title', '状态', 'Position', [20 65 560 60]);
    uilabel(panel1, 'Position', [10 20 40 22], 'Text', '状态:');
    statusLabel = uilabel(panel1, 'Position', [50 20 80 22], 'Text', '空闲',...
        'FontColor', [0 0 1], 'FontWeight', 'bold', 'FontSize', 12);
    uilabel(panel1, 'Position', [135 20 40 22], 'Text', '算式:');
    exprLabel = uilabel(panel1, 'Position', [175 20 120 22], 'Text', '-', 'FontWeight', 'bold');
    uilabel(panel1, 'Position', [300 20 40 22], 'Text', '结果:');
    resultLabel = uilabel(panel1, 'Position', [340 20 100 22], 'Text', '-',...
        'FontWeight', 'bold', 'FontColor', [0.8 0 0], 'FontSize', 12);
    uilabel(panel1, 'Position', [450 20 40 22], 'Text', '振幅:');
    ampLabel = uilabel(panel1, 'Position', [490 20 60 22], 'Text', '-');
    
    % 操作
    panel2 = uipanel(fig, 'Title', '操作', 'Position', [20 5 560 55]);
    sendExprBtn = uibutton(panel2, 'Position', [5 12 55 30], 'Text', '发算式', 'BackgroundColor', [0.8 1 0.8]);
    sendResultBtn = uibutton(panel2, 'Position', [65 12 55 30], 'Text', '发结果', 'BackgroundColor', [1 1 0.7]);
    recordBtn = uibutton(panel2, 'Position', [125 12 45 30], 'Text', '录音', 'BackgroundColor', [0.6 1 0.6]);
    stopBtn = uibutton(panel2, 'Position', [175 12 45 30], 'Text', '停止', 'BackgroundColor', [1 0.6 0.6]);
    decodeBtn = uibutton(panel2, 'Position', [225 12 45 30], 'Text', '译码');
    loopBtn = uibutton(panel2, 'Position', [275 12 55 30], 'Text', '回环', 'BackgroundColor', [0.9 0.9 1]);
    listenBtn = uibutton(panel2, 'Position', [335 12 50 30], 'Text', '监听', 'BackgroundColor', [0.7 0.9 1]);
    resendBtn = uibutton(panel2, 'Position', [390 12 45 30], 'Text', '重发', 'BackgroundColor', [1 0.8 0.6]);
    clearBtn = uibutton(panel2, 'Position', [440 12 35 30], 'Text', '清空');
    exampleBtn = uibutton(panel2, 'Position', [480 12 70 30], 'Text', '随机算式');
    
    % 回调
    roleGroup.SelectionChangedFcn = @(~,~) changeRole();
    strongListenCheck.ValueChangedFcn = @(~,~) toggleStrongListen();
    batchCheck.ValueChangedFcn = @(~,~) toggleBatchMode();
    sendExprBtn.ButtonPushedFcn = @(~,~) doSendExpr();
    sendResultBtn.ButtonPushedFcn = @(~,~) doSendResult();
    recordBtn.ButtonPushedFcn = @(~,~) startRecord();
    stopBtn.ButtonPushedFcn = @(~,~) stopRecord();
    decodeBtn.ButtonPushedFcn = @(~,~) doDecode();
    loopBtn.ButtonPushedFcn = @(~,~) doLoopback();
    listenBtn.ButtonPushedFcn = @(~,~) toggleListen();
    resendBtn.ButtonPushedFcn = @(~,~) doResend();
    clearBtn.ButtonPushedFcn = @(~,~) clearAll();
    exampleBtn.ButtonPushedFcn = @(~,~) generateRandomExpr();
    noiseBtn.ButtonPushedFcn = @(~,~) startNoise();
    noiseStopBtn.ButtonPushedFcn = @(~,~) stopNoise();
    noiseVolumeSlider.ValueChangedFcn = @(~,~) updateNoiseVolume();
    berTestBtn.ButtonPushedFcn = @(~,~) doBERTest();
    stopTestBtn.ButtonPushedFcn = @(~,~) stopBERTest();
    
    fig.CloseRequestFcn = @(~,~) cleanup();
    
    updateUIForRole();
    mylog('=== 天津大学无线计算器 V32 ===');
    mylog('Designed by Lily & Onlyone');
    mylog('新增:  误码率测试功能');
    
    function mylog(msg)
        t = datestr(now, 'HH:MM:SS');
        logEdit.Value = [logEdit.Value; {['[' t '] ' msg]}];
        scroll(logEdit, 'bottom');
        drawnow limitrate;
    end
    
    function setStatus(msg, color)
        statusLabel.Text = msg;
        statusLabel. FontColor = color;
        drawnow limitrate;
    end
    
    function clearAll()
        logEdit.Value = {''};
        exprLabel.Text = '-';
        resultLabel.Text = '-';
        ampLabel.Text = '-';
        berLabel.Text = 'BER: -';
        inputEdit.Value = '';
        audioData = [];
        mylog('已清空');
    end
    
    function generateRandomExpr()
        count = exprCountEdit.Value;
        exprs = {};
        for i = 1:count
            a = randi([1, 999]);
            b = randi([1, 999]);
            ops = {'+', '-', '*'};
            op = ops{randi(3)};
            exprs{end+1} = [num2str(a) op num2str(b)];
        end
        inputEdit.Value = {strjoin(exprs, ';')};
        mylog(['生成 ' num2str(count) ' 条随机算式']);
    end
    
    function toggleBatchMode()
        if batchCheck.Value
            mylog('批量模式开启');
        else
            mylog('批量模式关闭');
        end
    end
    
    function startNoise()
        if isPlayingNoise
            return;
        end
        volume = noiseVolumeSlider.Value;
        noise = volume * (2 * rand(sampling_freq * 120, 1) - 1);
        noisePlayer = audioplayer(noise, sampling_freq);
        play(noisePlayer);
        isPlayingNoise = true;
        noiseBtn.BackgroundColor = [1 0.5 0.5];
        noiseBtn. Text = '播放中';
        mylog(['噪声:  ' num2str(round(volume*100)) '%']);
    end
    
    function stopNoise()
        if ~isempty(noisePlayer) && isplaying(noisePlayer)
            stop(noisePlayer);
        end
        isPlayingNoise = false;
        noiseBtn.BackgroundColor = [0.9 0.7 0.7];
        noiseBtn.Text = '播放噪声';
    end
    
    function updateNoiseVolume()
        volume = noiseVolumeSlider.Value;
        noiseVolumeLabel.Text = [num2str(round(volume*100)) '%'];
        if isPlayingNoise
            stopNoise();
            startNoise();
        end
    end
    
    function changeRole()
        if senderRadio.Value
            isSender = true;
            roleLabel.Text = '当前:  发信者';
            roleLabel.FontColor = [0 0.5 0];
        else
            isSender = false;
            roleLabel.Text = '当前: 接收者';
            roleLabel.FontColor = [0 0 0.8];
        end
        updateUIForRole();
    end
    
    function toggleStrongListen()
        isStrongListen = strongListenCheck.Value;
    end
    
    function updateUIForRole()
        if isSender
            sendExprBtn.Enable = 'on';
            sendExprBtn.BackgroundColor = [0.8 1 0.8];
            sendResultBtn.Enable = 'off';
            sendResultBtn.BackgroundColor = [0.9 0.9 0.9];
        else
            sendExprBtn. Enable = 'off';
            sendExprBtn.BackgroundColor = [0.9 0.9 0.9];
            sendResultBtn.Enable = 'on';
            sendResultBtn.BackgroundColor = [1 1 0.7];
        end
    end
    
    function resultStr = formatResult(value)
        if isempty(value) || isnan(value) || isinf(value)
            resultStr = '0';
            return;
        end
        if value == floor(value)
            resultStr = num2str(floor(value));
            return;
        end
        resultStr = sprintf('%.4f', value);
        while length(resultStr) > 1 && resultStr(end) == '0'
            resultStr = resultStr(1:end-1);
        end
        if ~isempty(resultStr) && resultStr(end) == '.'
            resultStr = resultStr(1:end-1);
        end
        if isempty(resultStr)
            resultStr = '0';
        end
    end
    
    function valid = checkValidChars(str)
        validChars = '0123456789+-*/().;';
        valid = all(ismember(str, validChars));
    end
    
    function exprs = parseExpressions(str)
        parts = strsplit(strtrim(str), ';');
        exprs = parts(~cellfun('isempty', strtrim(parts)));
    end
    
    function resultsStr = formatBatchResults(results)
        strs = arrayfun(@(x) formatResult(x), results, 'UniformOutput', false);
        resultsStr = strjoin(strs, ';');
    end
    
    function results = parseBatchResults(str)
        parts = strsplit(str, ';');
        results = cellfun(@str2double, parts);
    end
    
    % ============ 误码率测试 ============
    function doBERTest()
        if isTesting
            mylog('测试已在进行中');
            return;
        end
        
        isTesting = true;
        berTestBtn.Enable = 'off';
        berTestBtn.BackgroundColor = [0.8 0.8 0.8];
        
        testCount = testCountEdit.Value;
        exprCount = exprCountEdit. Value;
        bit_duration = bitEdit.Value / 1000;
        
        mylog('');
        mylog('╔════════════════════════════════════════╗');
        mylog('║         误码率测试开始                 ║');
        mylog(['║  测试次数: ' sprintf('%-3d', testCount) '  每次算式数: ' sprintf('%-3d', exprCount) '      ║']);
        mylog('╚════════════════════════════════════════╝');
        
        totalBitsSent = 0;
        totalBitsError = 0;
        totalExprsSent = 0;
        totalExprsError = 0;
        successRounds = 0;
        
        for round = 1:testCount
            if ~isTesting
                mylog('测试被中止');
                break;
            end
            
            mylog('');
            mylog(['====== 第 ' num2str(round) '/' num2str(testCount) ' 轮 ======']);
            
            % 生成随机算式
            exprs = {};
            expectedResults = [];
            for i = 1:exprCount
                a = randi([1, 99]);
                b = randi([1, 99]);
                ops = {'+', '-', '*'};
                op = ops{randi(3)};
                expr = [num2str(a) op num2str(b)];
                exprs{end+1} = expr;
                expectedResults(end+1) = eval(expr);
            end
            
            allExprsStr = strjoin(exprs, ';');
            mylog(['发送:  ' allExprsStr]);
            
            % 编码
            code = encodeData(allExprsStr, false);
            sentBits = length(code);
            totalBitsSent = totalBitsSent + sentBits;
            totalExprsSent = totalExprsSent + exprCount;
            
            mylog(['编码:  ' num2str(sentBits) ' bits']);
            
            % 发送并录音
            sig = generateSignal(code);
            sigDur = length(sig) / sampling_freq;
            
            recObj = audiorecorder(sampling_freq, 16, 1);
            record(recObj);
            
            pause(0.3);
            sound(sig, sampling_freq);
            pause(sigDur + 0.8);
            
            stop(recObj);
            audioData = getaudiodata(recObj);
            
            amplitude = max(abs(audioData));
            ampLabel.Text = sprintf('%. 3f', amplitude);
            
            % 解码
            roundSuccess = false;
            roundBitErrors = 0;
            roundExprErrors = 0;
            
            try
                [~, decodedExpr, ~, ~, decodedBits] = decodeSignal(audioData, false);
                
                % 计算bit错误
                sentBitsArray = code - '0';
                if length(decodedBits) >= length(sentBitsArray)
                    bitErrors = sum(sentBitsArray ~= decodedBits(1:length(sentBitsArray)));
                else
                    bitErrors = sentBits;
                end
                roundBitErrors = bitErrors;
                totalBitsError = totalBitsError + bitErrors;
                
                % 解析并验证
                decodedExprs = parseExpressions(decodedExpr);
                
                if length(decodedExprs) == exprCount
                    exprErrors = 0;
                    for i = 1:exprCount
                        try
                            r = eval(decodedExprs{i});
                            if abs(r - expectedResults(i)) > 0.0001
                                exprErrors = exprErrors + 1;
                            end
                        catch
                            exprErrors = exprErrors + 1;
                        end
                    end
                    roundExprErrors = exprErrors;
                    
                    if exprErrors == 0
                        roundSuccess = true;
                        successRounds = successRounds + 1;
                        mylog(['√ 成功! bit错误: ' num2str(bitErrors)]);
                    else
                        mylog(['× 算式错误: ' num2str(exprErrors) '/' num2str(exprCount) ', bit错误: ' num2str(bitErrors)]);
                    end
                else
                    roundExprErrors = exprCount;
                    mylog(['× 算式数量不匹配: 期望' num2str(exprCount) ' 收到' num2str(length(decodedExprs))]);
                end
                
                totalExprsError = totalExprsError + roundExprErrors;
                
            catch e
                totalBitsError = totalBitsError + sentBits;
                totalExprsError = totalExprsError + exprCount;
                mylog(['× 解码失败: ' e.message]);
            end
            
            % 更新BER显示
            currentBER = totalBitsError / totalBitsSent * 100;
            berLabel. Text = ['BER: ' sprintf('%.2f', currentBER) '%'];
            
            setStatus(['测试 ' num2str(round) '/' num2str(testCount)], [0 0.5 0.8]);
            drawnow;
            
            % 间隔
            pause(0.5);
        end
        
        % 测试结果
        mylog('');
        mylog('╔════════════════════════════════════════╗');
        mylog('║           误码率测试结果               ║');
        mylog('╠════════════════════════════════════════╣');
        
        finalBER = totalBitsError / totalBitsSent * 100;
        exprErrorRate = totalExprsError / totalExprsSent * 100;
        roundSuccessRate = successRounds / testCount * 100;
        
        mylog(['║ 总发送bits:     ' sprintf('%-20d', totalBitsSent) '   ║']);
        mylog(['║ 错误bits:      ' sprintf('%-20d', totalBitsError) '   ║']);
        mylog(['║ 比特误码率:    ' sprintf('%-20s', [sprintf('%.4f', finalBER) '%']) '   ║']);
        mylog('╠════════════════════════════════════════╣');
        mylog(['║ 总发送算式:     ' sprintf('%-20d', totalExprsSent) '   ║']);
        mylog(['║ 错误算式:       ' sprintf('%-20d', totalExprsError) '   ║']);
        mylog(['║ 算式错误率:    ' sprintf('%-20s', [sprintf('%.2f', exprErrorRate) '%']) '   ║']);
        mylog('╠════════════════════════════════════════╣');
        mylog(['║ 成功轮数:      ' sprintf('%-3d', successRounds) '/' sprintf('%-3d', testCount) '                 ║']);
        mylog(['║ 轮次成功率:    ' sprintf('%-20s', [sprintf('%.1f', roundSuccessRate) '%']) '   ║']);
        mylog('╚════════════════════════════════════════╝');
        
        berLabel.Text = ['BER: ' sprintf('%.4f', finalBER) '%'];
        if finalBER == 0
            berLabel.FontColor = [0 0.6 0];
        elseif finalBER < 1
            berLabel.FontColor = [0.8 0.5 0];
        else
            berLabel.FontColor = [0.8 0 0];
        end
        
        isTesting = false;
        berTestBtn.Enable = 'on';
        berTestBtn.BackgroundColor = [1 0.9 0.6];
        setStatus('测试完成', [0 0.6 0]);
    end
    
    function stopBERTest()
        isTesting = false;
        mylog('正在停止测试...');
    end
    
    % ============ 其他功能函数 ============
    function sendRetransmitRequest()
        spb = round(sampling_freq * bit_duration);
        t_bit = (0: spb-1)' / sampling_freq;
        silence = zeros(round(sampling_freq * 0.3), 1);
        pattern = '10101010';
        sig = silence;
        for i = 1:length(pattern)
            if pattern(i) == '0'
                sig = [sig; 0.8 * sin(2*pi*freq_0*t_bit)];
            else
                sig = [sig; 0.8 * sin(2*pi*freq_1*t_bit)];
            end
        end
        sig = [sig; silence];
        sound(sig, sampling_freq);
        pause(length(sig)/sampling_freq + 0.3);
    end
    
    function isRetransmit = checkRetransmitRequest(bits)
        isRetransmit = false;
        pattern = [1 0 1 0 1 0 1 0];
        if length(bits) >= 8
            for i = 1:(length(bits)-7)
                if isequal(bits(i:i+7), pattern)
                    isRetransmit = true;
                    return;
                end
            end
        end
    end
    
    function doResend()
        if isempty(lastSentCode)
            mylog('无数据');
            return;
        end
        sig = generateSignal(lastSentCode);
        sound(sig, sampling_freq);
        setStatus('已重发', [0.8 0.5 0]);
    end
    
    function doSendExpr()
        if ~isSender
            mylog('请切换到发信者');
            return;
        end
        
        inputStr = strtrim(strjoin(inputEdit.Value, ''));
        if isempty(inputStr)
            mylog('请输入算式');
            return;
        end
        
        if ~checkValidChars(inputStr)
            mylog('包含不支持的字符');
            return;
        end
        
        bit_duration = bitEdit.Value / 1000;
        
        if batchCheck.Value || contains(inputStr, ';')
            exprs = parseExpressions(inputStr);
            allExprsStr = strjoin(exprs, ';');
            mylog(['发送 ' num2str(length(exprs)) ' 条算式']);
            
            code = encodeData(allExprsStr, false);
            mylog(['编码: ' num2str(length(code)) ' bits']);
            
            lastSentCode = code;
            batchExprs = exprs;
            
            sig = generateSignal(code);
            sound(sig, sampling_freq);
            
            setStatus('已发送', [0 0.6 0]);
            exprLabel.Text = [num2str(length(exprs)) '条'];
        else
            try
                r = eval(inputStr);
                mylog(['发送:  ' inputStr ' = ' formatResult(r)]);
                
                code = encodeData(inputStr, false);
                lastSentCode = code;
                
                sig = generateSignal(code);
                sound(sig, sampling_freq);
                
                setStatus('已发送', [0 0.6 0]);
                exprLabel.Text = inputStr;
            catch e
                mylog(['错误: ' e.message]);
            end
        end
    end
    
    function doSendResult()
        if isSender
            return;
        end
        
        bit_duration = bitEdit.Value / 1000;
        
        if ~isempty(batchResults)
            resultsStr = formatBatchResults(batchResults);
            code = encodeData(resultsStr, true);
            lastSentCode = code;
            sig = generateSignal(code);
            sound(sig, sampling_freq);
            mylog(['发送结果: ' resultsStr]);
            setStatus('已发送', [0 0.6 0]);
        else
            inputVal = strtrim(strjoin(inputEdit.Value, ''));
            if ~isempty(inputVal)
                code = encodeData(inputVal, true);
                lastSentCode = code;
                sig = generateSignal(code);
                sound(sig, sampling_freq);
                mylog(['发送: ' inputVal]);
                setStatus('已发送', [0 0.6 0]);
            end
        end
    end
    
    function startRecord()
        recObj = audiorecorder(sampling_freq, 16, 1);
        record(recObj);
        setStatus('录音中', [0.8 0 0]);
        mylog('录音开始');
        recordBtn.Enable = 'off';
    end
    
    function stopRecord()
        if ~isempty(recObj) && isrecording(recObj)
            stop(recObj);
            audioData = getaudiodata(recObj);
            amplitude = max(abs(audioData));
            mylog(['录音完成 振幅=' sprintf('%.4f', amplitude)]);
            ampLabel.Text = sprintf('%.4f', amplitude);
            setStatus('录音完成', [0 0 1]);
            recordBtn.Enable = 'on';
        end
    end
    
    function doDecode()
        if isempty(audioData)
            mylog('无数据');
            return;
        end
        
        bit_duration = bitEdit.Value / 1000;
        mylog('===== 译码 =====');
        
        try
            [result, expr, isReply, ~, decodedBits] = decodeSignal(audioData, true);
            mylog(['二进制:  ' sprintf('%d', decodedBits)]);
            
            if isReply
                if contains(expr, ';')
                    results = parseBatchResults(expr);
                    mylog(['收到 ' num2str(length(results)) ' 个结果']);
                    resultLabel.Text = [num2str(length(results)) '个'];
                else
                    mylog(['收到结果: ' formatResult(result)]);
                    resultLabel.Text = formatResult(result);
                end
                resultLabel.FontColor = [0 0.6 0];
            else
                if contains(expr, ';')
                    exprs = parseExpressions(expr);
                    batchExprs = exprs;
                    batchResults = [];
                    for i = 1:length(exprs)
                        try
                            r = eval(exprs{i});
                            batchResults(end+1) = r;
                            mylog(['  ' exprs{i} ' = ' formatResult(r)]);
                        catch
                            batchResults(end+1) = NaN;
                        end
                    end
                    exprLabel.Text = [num2str(length(exprs)) '条'];
                    resultLabel.Text = formatBatchResults(batchResults);
                    inputEdit.Value = {formatBatchResults(batchResults)};
                else
                    calcResult = eval(expr);
                    mylog(['收到: ' expr ' = ' formatResult(calcResult)]);
                    exprLabel.Text = expr;
                    resultLabel.Text = formatResult(calcResult);
                    lastResult = calcResult;
                    lastExpr = expr;
                    inputEdit.Value = {formatResult(calcResult)};
                end
                resultLabel.FontColor = [0. 8 0 0];
            end
            setStatus('成功', [0 0.6 0]);
        catch e
            mylog(['失败: ' e.message]);
            setStatus('失败', [0.8 0 0]);
        end
    end
    
    function doLoopback()
        bit_duration = bitEdit.Value / 1000;
        inputStr = strtrim(strjoin(inputEdit.Value, ''));
        if isempty(inputStr)
            inputStr = '1+2;3*4;5+6';
        end
        
        mylog('====== 回环测试 ======');
        
        exprs = parseExpressions(inputStr);
        allExprsStr = strjoin(exprs, ';');
        
        expectedResults = [];
        for i = 1:length(exprs)
            expectedResults(end+1) = eval(exprs{i});
        end
        
        mylog(['发送: ' allExprsStr]);
        code = encodeData(allExprsStr, false);
        
        sig = generateSignal(code);
        sigDur = length(sig) / sampling_freq;
        
        recObj = audiorecorder(sampling_freq, 16, 1);
        record(recObj);
        pause(0.3);
        sound(sig, sampling_freq);
        pause(sigDur + 0.8);
        stop(recObj);
        audioData = getaudiodata(recObj);
        
        amplitude = max(abs(audioData));
        mylog(['振幅:  ' sprintf('%.4f', amplitude)]);
        
        try
            [~, decodedExpr, ~, ~, ~] = decodeSignal(audioData, false);
            decodedExprs = parseExpressions(decodedExpr);
            
            calcResults = [];
            for i = 1:length(decodedExprs)
                calcResults(end+1) = eval(decodedExprs{i});
            end
            
            % 回传结果
            resultsStr = formatBatchResults(calcResults);
            mylog(['回传:  ' resultsStr]);
            
            resultCode = encodeData(resultsStr, true);
            resultSig = generateSignal(resultCode);
            resultDur = length(resultSig) / sampling_freq;
            
            recObj = audiorecorder(sampling_freq, 16, 1);
            record(recObj);
            pause(0.3);
            sound(resultSig, sampling_freq);
            pause(resultDur + 0.8);
            stop(recObj);
            audioData = getaudiodata(recObj);
            
            [~, resultExpr, ~, ~, ~] = decodeSignal(audioData, false);
            receivedResults = parseBatchResults(resultExpr);
            
            allOK = true;
            for i = 1:min(length(calcResults), length(receivedResults))
                if abs(receivedResults(i) - calcResults(i)) > 0.0001
                    allOK = false;
                end
            end
            
            if allOK
                mylog('*** 回环成功 ***');
                setStatus('成功', [0 0.6 0]);
            else
                mylog('*** 结果不匹配 ***');
                setStatus('失败', [0.8 0 0]);
            end
            
        catch e
            mylog(['失败: ' e.message]);
            setStatus('失败', [0.8 0 0]);
        end
    end
    
    function toggleListen()
        if ~isListening
            isListening = true;
            listenBtn.Text = '停止';
            listenBtn.BackgroundColor = [1 0.7 0.7];
            setStatus('监听中', [0.2 0.6 0.8]);
            normalListenLoop();
        else
            isListening = false;
            listenBtn.Text = '监听';
            listenBtn. BackgroundColor = [0.7 0.9 1];
            setStatus('空闲', [0 0 1]);
            if ~isempty(recObj) && isrecording(recObj)
                stop(recObj);
            end
        end
    end
    
    function normalListenLoop()
        while isListening
            try
                bit_duration = bitEdit.Value / 1000;
                recObj = audiorecorder(sampling_freq, 16, 1);
                recordblocking(recObj, 5);
                
                if ~isListening
                    break;
                end
                
                audioData = getaudiodata(recObj);
                amplitude = max(abs(audioData));
                ampLabel.Text = sprintf('%.4f', amplitude);
                
                if amplitude > 0.03
                    mylog(['检测信号 振幅=' sprintf('%.4f', amplitude)]);
                    
                    try
                        [result, expr, isReply, ~, ~] = decodeSignal(audioData, false);
                        
                        if isSender && isReply
                            if contains(expr, ';')
                                results = parseBatchResults(expr);
                                mylog(['收到 ' num2str(length(results)) ' 个结果']);
                            else
                                mylog(['收到结果: ' formatResult(result)]);
                            end
                            resultLabel.Text = formatResult(result);
                            resultLabel.FontColor = [0 0.6 0];
                        elseif ~isSender && ~isReply
                            if contains(expr, ';')
                                exprs = parseExpressions(expr);
                                batchResults = [];
                                for i = 1:length(exprs)
                                    batchResults(end+1) = eval(exprs{i});
                                end
                                mylog(['收到 ' num2str(length(exprs)) ' 条算式']);
                                inputEdit.Value = {formatBatchResults(batchResults)};
                            else
                                calcResult = eval(expr);
                                mylog(['收到: ' expr ' = ' formatResult(calcResult)]);
                                inputEdit.Value = {formatResult(calcResult)};
                                lastResult = calcResult;
                            end
                            mylog('>>> 点击发结果 <<<');
                        end
                    catch
                    end
                end
                drawnow;
            catch
                pause(0.5);
            end
        end
    end
    
    function cleanup()
        isListening = false;
        isTesting = false;
        stopNoise();
        if ~isempty(recObj) && isrecording(recObj)
            stop(recObj);
        end
        delete(fig);
    end
    
    % ============ 编解码函数 ============
    function code = encodeData(data, isResult)
        if isResult
            startCode = '11110';
        else
            startCode = '11111';
        end
        
        len = length(data);
        if len > 127
            error('最多127字符');
        end
        lenCode = dec2bin(len, 7);
        
        dataCode = '';
        for i = 1:length(data)
            ch = data(i);
            if isKey(encoding_map, ch)
                dataCode = [dataCode, encoding_map(ch)];
            else
                error(['不支持:  ' ch]);
            end
        end
        
        code = [startCode, lenCode, dataCode];
    end
    
    function sig = generateSignal(code)
        spb = round(sampling_freq * bit_duration);
        t_bit = (0:spb-1)' / sampling_freq;
        
        silence_pre = zeros(round(sampling_freq * 0.3), 1);
        
        start_pattern = '0101';
        start_sig = [];
        for i = 1:length(start_pattern)
            if start_pattern(i) == '0'
                start_sig = [start_sig; 0.8 * sin(2*pi*freq_0*t_bit)];
            else
                start_sig = [start_sig; 0.8 * sin(2*pi*freq_1*t_bit)];
            end
        end
        
        data_sig = [];
        for i = 1:length(code)
            if code(i) == '0'
                tone = 0.8 * sin(2*pi*freq_0*t_bit);
            else
                tone = 0.8 * sin(2*pi*freq_1*t_bit);
            end
            data_sig = [data_sig; tone];
        end
        
        silence_post = zeros(round(sampling_freq * 0.3), 1);
        
        sig = [silence_pre; start_sig; data_sig; silence_post];
    end
    
    function [allBits, signalStart, confidence] = getRawBits(data)
        data = data(: );
        spb = round(sampling_freq * bit_duration);
        data = data - mean(data);
        
        bw = 300;
        [b0, a0] = butter(4, [(freq_0-bw) (freq_0+bw)]/(sampling_freq/2), 'bandpass');
        [b1, a1] = butter(4, [(freq_1-bw) (freq_1+bw)]/(sampling_freq/2), 'bandpass');
        
        bp0 = filtfilt(b0, a0, data);
        bp1 = filtfilt(b1, a1, data);
        
        env0 = abs(bp0);
        env1 = abs(bp1);
        
        total_env = env0 + env1;
        win_size = round(spb / 4);
        total_smooth = movmean(total_env, win_size);
        
        threshold = max(total_smooth) * 0.3;
        signalStart = find(total_smooth > threshold, 1, 'first');
        
        if isempty(signalStart)
            error('无信号');
        end
        
        allBits = [];
        confidences = [];
        pos = signalStart;
        
        while pos + spb <= length(data)
            margin = round(spb * 0.2);
            sample_start = pos + margin;
            sample_end = pos + spb - margin;
            
            if sample_end > length(env0)
                break;
            end
            
            e0 = mean(env0(sample_start: sample_end));
            e1 = mean(env1(sample_start:sample_end));
            
            if e1 > e0
                allBits = [allBits, 1];
            else
                allBits = [allBits, 0];
            end
            
            total_e = e0 + e1;
            if total_e > 0
                confidences = [confidences, abs(e1 - e0) / total_e];
            end
            
            pos = pos + spb;
        end
        
        confidence = mean(confidences);
    end
    
    function [result, expr, isReply, debugInfo, decodedBits] = decodeSignal(data, doDebug)
        debugInfo = {};
        isReply = false;
        result = 0;
        decodedBits = [];
        
        [allBits, signalStart, confidence] = getRawBits(data);
        
        if doDebug
            debugInfo{end+1} = ['起始:  ' num2str(signalStart) ', bits: ' num2str(length(allBits))];
        end
        
        start_pattern = [0 1 0 1];
        found_start = -1;
        for i = 1:(length(allBits) - 16)
            if isequal(allBits(i:i+3), start_pattern)
                found_start = i + 4;
                break;
            end
        end
        
        if found_start < 0
            error('无同步码');
        end
        
        bits = allBits(found_start:end);
        
        if length(bits) < 12
            error('数据不足');
        end
        
        startCode = bits(1:5);
        if isequal(startCode, [1 1 1 1 0])
            isReply = true;
        elseif isequal(startCode, [1 1 1 1 1])
            isReply = false;
        else
            d0 = sum(startCode ~= [1 1 1 1 0]);
            d1 = sum(startCode ~= [1 1 1 1 1]);
            if d0 <= 1
                isReply = true;
            elseif d1 <= 1
                isReply = false;
            else
                error('类型码错误');
            end
        end
        
        lenBits = bits(6:12);
        exprLen = lenBits(1)*64 + lenBits(2)*32 + lenBits(3)*16 + lenBits(4)*8 + lenBits(5)*4 + lenBits(6)*2 + lenBits(7);
        
        if exprLen == 0 || exprLen > 127
            error(['长度错误: ' num2str(exprLen)]);
        end
        
        totalBitsNeeded = 12 + exprLen * 5;
        if length(bits) < totalBitsNeeded
            error('数据不完整');
        end
        
        decodedBits = bits(1:totalBitsNeeded);
        
        expr = '';
        for i = 1:exprLen
            bitStart = 12 + (i-1)*5 + 1;
            bitEnd = bitStart + 4;
            charBits = bits(bitStart:bitEnd);
            charCode = sprintf('%d%d%d%d%d', charBits(1), charBits(2), charBits(3), charBits(4), charBits(5));
            
            if isKey(decoding_map, charCode)
                expr = [expr, decoding_map(charCode)];
            else
                error(['未知编码: ' charCode]);
            end
        end
        
        if doDebug
            debugInfo{end+1} = ['解码: ' expr];
        end
        
        if isReply && ~contains(expr, ';')
            result = str2double(expr);
        end
    end
end