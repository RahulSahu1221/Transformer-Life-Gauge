function transformer_life_gauge_dashboard()
%TRANSFORMER_LIFE_GAUGE_DASHBOARD  (Premium / Speedometer Edition)
% Full interactive, live-running simulation dashboard for the
% Transformer Life Gauge project. Implements the complete 4-step
% IEEE C57.91 thermal aging model, real speedometer-style gauges,
% alarm lamps, live-labeled sliders, the Dynamic Loading Advisor,
% and two auto-run scenarios.
%
% Built entirely with classic figure/uicontrol/axes components
% (no uifigure/uilabel/uigauge/App Designer widgets), so it runs on
% any standard MATLAB install, no extra toolboxes needed.
%
% HOW TO RUN: open this file in MATLAB and press Run (or type
% transformer_life_gauge_dashboard in the Command Window).

    %% ---------------- Model constants (design/test data) ----------------
    C.R              = 5.0;
    C.dTheta_TO      = 45.0;
    C.dTheta_HS      = 20.0;
    C.n_exp          = 0.8;
    C.m_exp          = 0.8;
    C.ratedLifeHours = 180000;
    C.ratedHotspot   = 110;     % C -- rated reference (context only; alarms use +15/+25 below)
    C.warnHS         = C.ratedHotspot + 15;   % 125 C
    C.critHS         = C.ratedHotspot + 25;   % 135 C

    %% ---------------- Shared simulation state ----------------
    S.totalAgedHours = 0;
    S.simHours       = 0;
    S.warnFAAHours   = 0;
    S.running        = false;
    S.scenario       = 'Manual';
    S.scenarioClockH = 0;
    S.histT    = [];
    S.histLife = [];
    maxHistPts = 4000;
    S.smoothLife = 100;
    S.smoothHS   = 40;

    %% ---------------- Theme palette ----------------
    bgDark      = [0.06 0.08 0.12];
    panelDark   = [0.10 0.12 0.17];
    fieldDark   = [0.15 0.18 0.24];
    textLight   = [0.92 0.95 0.98];
    textMuted   = [0.58 0.65 0.73];
    accentTeal  = [0.20 0.60 0.68];
    accentAmber = [0.95 0.65 0.20];
    green  = [0.25 0.78 0.48];
    yellow = [0.95 0.70 0.25];
    red    = [0.92 0.32 0.32];

    fontName = 'Segoe UI';

    %% ================= BUILD THE UI ==================
    fig = figure('Name','Transformer Life Gauge -- Live Simulation Dashboard', ...
                 'NumberTitle','off','Color',bgDark, ...
                 'MenuBar','none','ToolBar','none','Resize','off', ...
                 'Position',[60 15 1220 920]);
    fig.CloseRequestFcn = @(~,~) onClose();

    % ---- Row geometry ----
    colX = [20 420 820];  colW = 380;
    topY = 620;  topH = 260;
    midY = 300;  midH = 300;
    botY = 20;   botH = 260;

    %% ---- Panel A: Life Remaining Gauge ----
    pLife = panelDarkStyle(fig,'LIFE REMAINING',[colX(1) topY colW topH]);
    gLife = buildGauge(pLife, [10 15 colW-20 topH-45], 0, 100, ...
                        [0 10 red; 10 20 yellow; 20 100 green], '%');

    %% ---- Panel B: Winding Hot-Spot Temperature Gauge ----
    pHS = panelDarkStyle(fig,'WINDING HOT-SPOT TEMPERATURE',[colX(2) topY colW topH]);
    gHS = buildGauge(pHS, [10 15 colW-20 topH-45], 0, 240, ...
                      [0 C.warnHS green; C.warnHS C.critHS yellow; C.critHS 240 red], 'C');

    %% ---- Panel C: Live Parameters & Alarms ----
    pStatus = panelDarkStyle(fig,'LIVE PARAMETERS & ALARMS',[colX(3) topY colW topH]);
    
    rowLbl(pStatus, textLight, textMuted, fieldDark, fontName, 215, 'Oil Temperature');
    lblOil = valLbl(pStatus, textLight, fieldDark, fontName, 215);
    
    rowLbl(pStatus, textLight, textMuted, fieldDark, fontName, 190, 'Aging Factor (F_{AA})');
    lblFAA = valLbl(pStatus, textLight, fieldDark, fontName, 190);
    
    rowLbl(pStatus, textLight, textMuted, fieldDark, fontName, 165, 'Load (% Rated)');
    lblLoad = valLbl(pStatus, textLight, fieldDark, fontName, 165);
    
    rowLbl(pStatus, textLight, textMuted, fieldDark, fontName, 140, 'Ambient Temperature');
    lblAmbient = valLbl(pStatus, textLight, fieldDark, fontName, 140);
    
    rowLbl(pStatus, textLight, textMuted, fieldDark, fontName, 115, 'Operating Hours');
    lblSim = valLbl(pStatus, textLight, fieldDark, fontName, 115);
    
    [lampHS, lblHSAlarm]     = lampRow(pStatus, panelDark, textLight, fontName, green, 80, 'Hot-Spot: OK');
    [lampFAA, lblFAAAlarm]   = lampRow(pStatus, panelDark, textLight, fontName, green, 50,  'Aging Rate: OK');
    [lampLife, lblLifeAlarm] = lampRow(pStatus, panelDark, textLight, fontName, green, 20,  'Life Level: OK');

    %% ---- Panel D: Manual Controls & Scenarios ----
    pCtrl = panelDarkStyle(fig,'MANUAL CONTROLS & SCENARIOS',[colX(1) midY colW midH]);

    [sldAmbient, lblAmbVal] = sliderBlock(pCtrl, panelDark, fieldDark, textLight, textMuted, fontName, ...
                     210, 'Ambient Temperature', 15, 55, 30, 'C', '15 - 55 C');
    [sldLoad, lblLoadVal]   = sliderBlock(pCtrl, panelDark, fieldDark, textLight, textMuted, fontName, ...
                     140, 'Load (% of Rated)', 0, 200, 60, '%', '0 - 200 % of rated');
    [sldSpeed, lblSpeedVal] = sliderBlock(pCtrl, panelDark, fieldDark, textLight, textMuted, fontName, ...
                     70, 'Simulation Speed', 1, 48, 12, 'hrs/s', '1 - 48 simulated hrs per real second');

    uicontrol(pCtrl,'Style','text','String','Scenario','FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textMuted,'BackgroundColor',panelDark,'HorizontalAlignment','left', ...
              'Position',[15 32 100 18]);
    ddScenario = uicontrol(pCtrl,'Style','popupmenu', ...
              'String',{'Manual','Typical Daily Profile','Emergency Overload Event'}, ...
              'BackgroundColor',fieldDark,'ForegroundColor',textLight,'FontName',fontName, ...
              'Position',[120 30 235 22]);

    btnStart = uicontrol(pCtrl,'Style','pushbutton','String','START','FontWeight','bold', ...
              'FontName',fontName,'BackgroundColor',accentTeal,'ForegroundColor',[1 1 1], ...
              'Position',[15 2 110 26],'Callback',@(~,~) onStart());
    btnStop  = uicontrol(pCtrl,'Style','pushbutton','String','PAUSE','FontName',fontName, ...
              'BackgroundColor',fieldDark,'ForegroundColor',textLight, ...
              'Position',[132 2 110 26],'Callback',@(~,~) onStop());
    btnReset = uicontrol(pCtrl,'Style','pushbutton','String','RESET','FontName',fontName, ...
              'BackgroundColor',[0.35 0.18 0.18],'ForegroundColor',[1 0.9 0.9], ...
              'Position',[249 2 106 26],'Callback',@(~,~) onReset());

    updateSliderLabels();

    %% ---- Panel E: Dynamic Loading Advisor (Step 4) ----
    pDLA = panelDarkStyle(fig,'DYNAMIC LOADING ADVISOR (STEP 4)',[colX(2) midY colW midH]);
    uicontrol(pDLA,'Style','text','String','Proposed extra load (%)','FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textMuted,'BackgroundColor',panelDark,'HorizontalAlignment','left', ...
              'Position',[15 250 220 18]);
    efOverload = uicontrol(pDLA,'Style','edit','String','10','FontName',fontName, ...
              'BackgroundColor',fieldDark,'ForegroundColor',textLight,'Position',[15 225 340 26]);

    uicontrol(pDLA,'Style','text','String','Proposed duration (hours)','FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textMuted,'BackgroundColor',panelDark,'HorizontalAlignment','left', ...
              'Position',[15 190 220 18]);
    efDuration = uicontrol(pDLA,'Style','edit','String','3','FontName',fontName, ...
              'BackgroundColor',fieldDark,'ForegroundColor',textLight,'Position',[15 165 340 26]);

    btnCalcDLA = uicontrol(pDLA,'Style','pushbutton','String','CALCULATE SAFE OVERLOAD IMPACT', ...
              'FontName',fontName,'FontWeight','bold','BackgroundColor',accentAmber,'ForegroundColor',[0.15 0.1 0], ...
              'Position',[15 120 340 34],'Callback',@(~,~) onCalcDLA());

    lblDLAResult = uicontrol(pDLA,'Style','text','String','Result: --','FontWeight','bold','FontName',fontName, ...
              'ForegroundColor',textLight,'HorizontalAlignment','left','BackgroundColor',panelDark, ...
              'Position',[15 55 340 55]);
    lblDLAResultHS = uicontrol(pDLA,'Style','text','String','','FontName',fontName, ...
              'ForegroundColor',textMuted,'HorizontalAlignment','left','BackgroundColor',panelDark, ...
              'Position',[15 15 340 35]);

    %% ---- Panel F: Industry Failure Data (static reference chart) ----
    pInd = panelDarkStyle(fig,'INDUSTRY FAILURE DATA (CIGRE)',[colX(3) midY colW midH]);
    axInd = axes('Parent',pInd,'Units','pixels','Position',[55 70 300 210], ...
                 'Color',panelDark,'XColor',textMuted,'YColor',textMuted,'FontName',fontName);
    bInd = bar(axInd, categorical({'Design & Mfg','Insulation Ageing','Improper Maint.'}), [20 15 10]);
    bInd.FaceColor = 'flat';
    bInd.CData = [accentTeal; accentAmber; red];
    ylabel(axInd,'% of known causes','Color',textMuted);
    ylim(axInd,[0 25]);
    axInd.XColor = textMuted;
    axInd.YColor = textMuted;
    grid(axInd,'on'); axInd.GridColor = textMuted; axInd.GridAlpha = 0.25;
    %% ---- Panel G: Live Trend Plot ----
    pTrend = panelDarkStyle(fig,'LIVE TREND: LIFE REMAINING % OVER SIMULATED TIME',[colX(1) botY 1180 botH]);
    axTrend = axes('Parent',pTrend,'Units','pixels','Position',[65 45 1095 190], ...
                   'Color',panelDark,'XColor',textMuted,'YColor',textMuted,'FontName',fontName);
    xlabel(axTrend,'Simulated Time (hours)','Color',textMuted);
    ylabel(axTrend,'Life Remaining (%)','Color',textMuted);
    ylim(axTrend,[0 100]);
    grid(axTrend,'on'); axTrend.GridColor = textMuted; axTrend.GridAlpha = 0.25;
    hold(axTrend,'on');
    hLine = plot(axTrend, nan, nan, 'Color', green, 'LineWidth', 2.2);

    %% ================= TIMER (the live "clock") ==================
    dtReal = 0.033; % Updates at ~30 FPS for smooth animation
    tmr = timer('ExecutionMode','fixedRate','Period',dtReal,'TimerFcn',@(~,~) tick());
    tmr.BusyMode = 'drop';

    %% ================= CALLBACKS ==================
    function updateSliderLabels()
        set(lblAmbVal,'String',sprintf('%.1f C', get(sldAmbient,'Value')));
        set(lblLoadVal,'String',sprintf('%.0f %%', get(sldLoad,'Value')));
        set(lblSpeedVal,'String',sprintf('%.0f hrs/s', get(sldSpeed,'Value')));
    end

    function onStart()
        S.running = true;
        items = get(ddScenario,'String');
        S.scenario = items{get(ddScenario,'Value')};
        S.scenarioClockH = 0;
        if strcmp(get(tmr,'Running'),'off')
            start(tmr);
        end
    end

    function onStop()
        S.running = false;
    end

    function onReset()
        S.running = false;
        S.totalAgedHours = 0;
        S.simHours = 0;
        S.warnFAAHours = 0;
        S.scenarioClockH = 0;
        S.histT = [];
        S.histLife = [];
        S.smoothLife = 100;
        S.smoothHS = 40;
        set(hLine,'XData',nan,'YData',nan);
        updateGauge(gLife, 100, green, 'HEALTHY', '%.2f');
        updateGauge(gHS, 40, green, 'OK', '%.1f');
        set(lblSim,'String','0.0 hrs');
        setLamp(lampHS, green, panelDark); set(lblHSAlarm,'String','Hot-Spot: OK');
        setLamp(lampFAA, green, panelDark); set(lblFAAAlarm,'String','Aging Rate: OK');
        setLamp(lampLife, green, panelDark); set(lblLifeAlarm,'String','Life Level: OK');
        updateSliderLabels();
    end

    function onCalcDLA()
        ambientTemp = get(sldAmbient,'Value');
        Kcur = get(sldLoad,'Value')/100;
        overloadPct = str2double(get(efOverload,'String'));
        hrs = str2double(get(efDuration,'String'));
        if isnan(overloadPct), overloadPct = 0; end
        if isnan(hrs), hrs = 0; end
        Ktest = Kcur + overloadPct/100;
        [thetaH_t, F_AA_t] = stepModel(ambientTemp, Ktest, C);
        extraCost = (F_AA_t * hrs / C.ratedLifeHours) * 100;
        set(lblDLAResult,'String',sprintf('Result: +%.0f%% load for %.1f hrs costs ~%.5f%% of total life', ...
                                     overloadPct, hrs, extraCost));
        set(lblDLAResultHS,'String',sprintf('Resulting hot-spot temperature: %.1f C  (F_{AA} = %.2f)', ...
                                      thetaH_t, F_AA_t));
    end

    function onClose()
        try
            stop(tmr); delete(tmr);
        catch
        end
        delete(fig);
    end

    %% ================= MAIN SIMULATION TICK ==================
    function tick()
        if ~S.running
            updateSliderLabels();
            return;
        end

        speedVal = get(sldSpeed,'Value');
        dtSimHours = dtReal * speedVal;

        switch S.scenario
            case 'Typical Daily Profile'
                S.scenarioClockH = S.scenarioClockH + dtSimHours;
                th = mod(S.scenarioClockH,24);
                ambientTemp = 30 + 5*sin(2*pi*(th-9)/24);
                K = 0.35 + 0.45*max(0,sin(pi*(th-6)/14)) + 0.15*exp(-((th-14)^2)/8);
                K = min(K,1.25);
                set(sldAmbient,'Value',ambientTemp); set(sldLoad,'Value',K*100);
                if S.scenarioClockH >= 24
                    S.running = false;
                end
            case 'Emergency Overload Event'
                S.scenarioClockH = S.scenarioClockH + dtSimHours;
                ambientTemp = 35;
                if S.scenarioClockH < 2
                    K = 0.6;
                elseif S.scenarioClockH < 6
                    K = 1.3;
                else
                    K = 0.6;
                end
                set(sldAmbient,'Value',ambientTemp); set(sldLoad,'Value',K*100);
                if S.scenarioClockH >= 10
                    S.running = false;
                end
            otherwise
                ambientTemp = get(sldAmbient,'Value');
                K = get(sldLoad,'Value')/100;
        end

        updateSliderLabels();

        [thetaH, F_AA, thetaTO] = stepModel(ambientTemp, K, C);
        S.totalAgedHours = S.totalAgedHours + F_AA*dtSimHours;
        S.simHours = S.simHours + dtSimHours;
        lifeUsed = (S.totalAgedHours / C.ratedLifeHours) * 100;
        lifeRemaining = max(0,min(100, 100 - lifeUsed));

    % ---- Calculate Gauge Colors / Status ----
    if lifeRemaining < 10
        lifeColor = red; lifeStatus = 'CRITICAL';
    elseif lifeRemaining < 20
        lifeColor = yellow; lifeStatus = 'WARNING';
    else
        lifeColor = green; lifeStatus = 'HEALTHY';
    end

    if thetaH > C.critHS
        hsColor = red; hsStatus = 'CRITICAL';
    elseif thetaH > C.warnHS
        hsColor = yellow; hsStatus = 'WARNING';
    else
        hsColor = green; hsStatus = 'OK';
    end

    % ---- Apply Physical Inertia (Smoothing) to the Pointers ----
    % This moves the needle a smooth percentage of the way to the target each frame
    inertia = 0.10; 
    S.smoothLife = S.smoothLife + inertia * (lifeRemaining - S.smoothLife);
    S.smoothHS   = S.smoothHS + inertia * (thetaH - S.smoothHS);

    % ---- Update Gauges with Smoothed Values ----  
    updateGauge(gLife, S.smoothLife, lifeColor, lifeStatus, '%.3f');
    updateGauge(gHS, S.smoothHS, hsColor, hsStatus, '%.1f');

    % ---- Labels ----
    set(lblOil,'String',sprintf('%.1f C',thetaTO));
    set(lblFAA,'String',sprintf('%.3f x',F_AA));
    set(lblLoad,'String',sprintf('%.0f %%',K*100));
    set(lblAmbient,'String',sprintf('%.1f C',ambientTemp));
    set(lblSim,'String',sprintf('%.1f hrs',S.simHours));

        % ---- Alarm lamps ----
        if thetaH > C.critHS
            setLamp(lampHS,red,panelDark); set(lblHSAlarm,'String','CRITICAL: Reduce load now');
        elseif thetaH > C.warnHS
            setLamp(lampHS,yellow,panelDark); set(lblHSAlarm,'String','Warning: Check cooling');
        else
            setLamp(lampHS,green,panelDark); set(lblHSAlarm,'String','Hot-Spot: OK');
        end

        if F_AA > 4
            S.warnFAAHours = S.warnFAAHours + dtSimHours;
        else
            S.warnFAAHours = 0;
        end
        if S.warnFAAHours >= 1
            setLamp(lampFAA,yellow,panelDark); set(lblFAAAlarm,'String','Warning: Aging 4x+ sustained');
        else
            setLamp(lampFAA,green,panelDark); set(lblFAAAlarm,'String','Aging Rate: OK');
        end

        if lifeRemaining < 10
            setLamp(lampLife,red,panelDark); set(lblLifeAlarm,'String','CRITICAL: Inspect / DGA test');
        elseif lifeRemaining < 20
            setLamp(lampLife,yellow,panelDark); set(lblLifeAlarm,'String','Warning: Plan inspection');
        else
            setLamp(lampLife,green,panelDark); set(lblLifeAlarm,'String','Life Level: OK');
        end

        % ---- Trend plot ----
        S.histT(end+1) = S.simHours;
        S.histLife(end+1) = lifeRemaining;
        if numel(S.histT) > maxHistPts
            S.histT(1) = [];
            S.histLife(1) = [];
        end
        set(hLine,'XData',S.histT,'YData',S.histLife,'Color',lifeColor);
        xEnd = max(1, S.simHours);
        xlim(axTrend,[max(0,xEnd-48), xEnd+0.01]);

        drawnow limitrate;
    end
end

%% ================= HELPER: MODEL ==================
function [thetaH, F_AA, thetaTO] = stepModel(ambientTemp, K, C)
    oilRise = C.dTheta_TO * ((1 + K^2*C.R)/(1+C.R))^C.n_exp;
    hsRise  = C.dTheta_HS * K^(2*C.m_exp);
    thetaTO = ambientTemp + oilRise;
    thetaH  = thetaTO + hsRise;
    F_AA    = exp((15000/383) - (15000/(thetaH+273)));
end

%% ================= HELPER: THEME / LAYOUT WIDGETS ==================
function p = panelDarkStyle(fig, titleStr, pos)
    panelDark = [0.10 0.12 0.17];
    textLight = [0.92 0.95 0.98];
    accentTeal = [0.20 0.60 0.68];
    p = uipanel(fig,'Title',[' ' titleStr ' '],'FontWeight','bold','FontSize',10, ...
                'FontName','Segoe UI','ForegroundColor',textLight, ...
                'BackgroundColor',panelDark,'HighlightColor',accentTeal, ...
                'BorderType','line','Units','pixels','Position',pos);
end

function rowLbl(parent, textLight, textMuted, fieldDark, fontName, y, str) %#ok<INUSD>
    uicontrol(parent,'Style','text','String',str,'FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textMuted,'BackgroundColor',[0.10 0.12 0.17], ...
              'HorizontalAlignment','left','Position',[15 y 190 20]);
end

function h = valLbl(parent, textLight, fieldDark, fontName, y) %#ok<INUSL>
    h = uicontrol(parent,'Style','text','String','--','FontName',fontName,'FontSize',11, ...
              'FontWeight','bold','ForegroundColor',textLight,'BackgroundColor',[0.10 0.12 0.17], ...
              'HorizontalAlignment','right','Position',[205 y 155 20]);
end

function [lamp, lbl] = lampRow(parent, panelDark, textLight, fontName, initColor, y, initStr)
    lamp = uicontrol(parent,'Style','text','BackgroundColor',initColor,'Position',[15 y 18 18]);
    lbl = uicontrol(parent,'Style','text','String',initStr,'FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textLight,'BackgroundColor',panelDark, ...
              'HorizontalAlignment','left','Position',[42 y 320 20]);
end

function setLamp(lampHandle, rgb, ~)
    set(lampHandle,'BackgroundColor',rgb);
end

function [sld, valLabel] = sliderBlock(parent, panelDark, fieldDark, textLight, textMuted, fontName, ...
                                        y, labelStr, vmin, vmax, vinit, unitStr, rangeStr) %#ok<INUSL>
    uicontrol(parent,'Style','text','String',labelStr,'FontName',fontName,'FontSize',10, ...
              'ForegroundColor',textMuted,'BackgroundColor',panelDark, ...
              'HorizontalAlignment','left','Position',[15 y+42 200 18]);
    valLabel = uicontrol(parent,'Style','text','String',sprintf('%.1f %s',vinit,unitStr), ...
              'FontName',fontName,'FontSize',11,'FontWeight','bold', ...
              'ForegroundColor',textLight,'BackgroundColor',panelDark, ...
              'HorizontalAlignment','right','Position',[220 y+42 135 18]);
              
    % Added a slate-grey BackgroundColor so the white handle is easily visible
    sld = uicontrol(parent,'Style','slider','Min',vmin,'Max',vmax,'Value',vinit, ...
              'BackgroundColor', [0.25 0.30 0.35], ...
              'Position',[15 y+20 340 18]);
              
    uicontrol(parent,'Style','text','String',['Range: ' rangeStr],'FontName',fontName,'FontSize',8.5, ...
              'ForegroundColor',textMuted,'BackgroundColor',panelDark, ...
              'HorizontalAlignment','left','Position',[15 y 340 16]);
end

%% ================= HELPER: SPEEDOMETER GAUGE ==================
function h = buildGauge(parent, pos, vmin, vmax, zones, unitStr)
    panelDark = [0.10 0.12 0.17];
    gaugeFace = [0.06 0.10 0.15]; % Deep dark navy/grey like the reference image
    tickColor = [0.95 0.90 0.70]; % Cream/pale yellow for ticks and text

    ax = axes('Parent',parent,'Units','pixels','Position',pos, ...
              'Color',panelDark,'XColor','none','YColor','none');
    axis(ax,'equal'); axis(ax,'off');
    xlim(ax,[-1.35 1.35]); ylim(ax,[-1.15 1.3]);
    hold(ax,'on');

    % 1. Draw the gauge face background (dark circular dial)
    th = linspace(0, 360, 200);
    fill(ax, 1.3*cosd(th), 1.3*sind(th), gaugeFace, 'EdgeColor', [0.3 0.4 0.5], 'LineWidth', 1.5);

    % 2. Draw static subtle background track for the dynamic value bar
    rOuter = 1.25;
    rInner = 1.05;
    aMin = angleForValue(vmin, vmin, vmax);
    aMax = angleForValue(vmax, vmin, vmax);
    tt = linspace(aMin, aMax, 100);
    xArc = [rInner*cosd(tt), rOuter*cosd(fliplr(tt))];
    yArc = [rInner*sind(tt), rOuter*sind(fliplr(tt))];
    fill(ax, xArc, yArc, [0.1 0.15 0.2], 'EdgeColor', 'none'); % Subtle background track

    % 3. Initialize the dynamic "Value Bar" patch
    hValueBar = patch(ax, 'XData', [], 'YData', [], 'FaceColor', [1 0.5 0], 'EdgeColor', 'none');

    % 4. Ticks and Labels
    % Dynamic intervals based on the gauge's max value
    if vmax <= 100
        majorTicks = 0:20:vmax;
        minorTicks = 0:10:vmax;
    else
        majorTicks = 0:40:vmax;
        minorTicks = 0:20:vmax;
    end

    % Because ticks are drawn AFTER the value bar, they will naturally 
    % layer on top, creating those cool segment gaps seen in the image!
    for tv = minorTicks
        ta = angleForValue(tv, vmin, vmax);
        plot(ax, [1.05*cosd(ta) 1.25*cosd(ta)], [1.05*sind(ta) 1.25*sind(ta)], ...
             'Color', tickColor*0.7, 'LineWidth', 1);
    end

    for tv = majorTicks
        ta = angleForValue(tv, vmin, vmax);
        plot(ax, [1.05*cosd(ta) 1.25*cosd(ta)], [1.05*sind(ta) 1.25*sind(ta)], ...
             'Color', tickColor, 'LineWidth', 2.5);
        text(ax, 0.75*cosd(ta), 0.75*sind(ta), sprintf('%g',tv), ...
             'Color', tickColor, 'FontSize', 11, 'FontWeight', 'bold', 'HorizontalAlignment','center');
    end

    % 5. Central Unit, Boxed Value, and Status Text
    
    % Keep the unit text tucked neatly under the pivot
    hUnitText = text(ax,0,-0.35,unitStr,'FontSize',14,'FontWeight','bold', ...
                     'HorizontalAlignment','center','Color',tickColor*0.8);

    % Create the boxed digital value display with smaller text and tighter margins
    boxBgColor = [0.04 0.06 0.09]; 
    boxEdgeColor = [0.3 0.4 0.5];   
    hValText = text(ax,0,-0.72,'--','FontSize',12,'FontWeight','bold', ...
                     'HorizontalAlignment','center','Color',[1 1 1], ...
                     'BackgroundColor', boxBgColor, ...
                     'EdgeColor', boxEdgeColor, ...
                     'LineWidth', 1.2, 'Margin', 3); % Thinner border, tighter margin

    % Nudge the status text down just a hair more for perfectly clean spacing
    hStatusText = text(ax,0,-1.08,'','FontSize',12,'FontWeight','bold', ...
                       'HorizontalAlignment','center');
    % 6. Needle and Hollow Pivot Ring (Red)
    needleColor = [0.85 0.15 0.15];
    rPivot = 0.12; % Size of the hollow center ring
    
    % The needle line starts just outside the pivot ring
    hNeedle = plot(ax, [0 0], [rPivot 1.05], 'Color', needleColor, 'LineWidth', 3.5);
    
    % Draw the hollow pivot ring
    ttCircle = linspace(0, 360, 50);
    plot(ax, rPivot*cosd(ttCircle), rPivot*sind(ttCircle), 'Color', needleColor, 'LineWidth', 3.5);

    % Store all handles
    h = struct('ax',ax,'needle',hNeedle,'valueBar',hValueBar, 'valText',hValText,'statusText',hStatusText, ...
                'vmin',vmin,'vmax',vmax);
end

function updateGauge(h, value, statusColor, statusStr, fmt)
    theta = angleForValue(value, h.vmin, h.vmax);
    
    % 1. Update Needle
    r = 1.05;
    rPivot = 0.12; % Keep the line outside the hollow ring
    set(h.needle, 'XData', [rPivot*cosd(theta) r*cosd(theta)], ...
                  'YData', [rPivot*sind(theta) r*sind(theta)]);
    
    % 2. Update Dynamic Value Bar Arc
    theta_start = angleForValue(h.vmin, h.vmin, h.vmax);
    
    % Generate the sweep from the minimum value up to the current needle position
    tt = linspace(theta_start, theta, 50);
    rOuter = 1.25;
    rInner = 1.05;
    
    xArc = [rInner*cosd(tt), rOuter*cosd(fliplr(tt))];
    yArc = [rInner*sind(tt), rOuter*sind(fliplr(tt))];
    
    % Apply the new shape and match the fill color to the current status (green/yellow/red)
    set(h.valueBar, 'XData', xArc, 'YData', yArc, 'FaceColor', statusColor);

    % 3. Update Digital Text
    set(h.valText, 'String', sprintf(fmt, value), 'Color', statusColor);
    set(h.statusText, 'String', statusStr, 'Color', statusColor);
end

function a = angleForValue(v, vmin, vmax)
    frac = (v - vmin) / (vmax - vmin);
    frac = max(0, min(1, frac));
    % Sweeps 270 degrees: starting at 225 deg (bottom left) to -45 deg (bottom right)
    a = 225 - frac * 270;   
end
