param(
    [string]$TemplatePath = "C:\Users\Piyush\Downloads\Prototype Submission Deck _ Gen AI Academy APAC Edition.pptx",
    [string]$OutputPath = "C:\Users\Piyush\workspace\hackhathon\submission_assets\Multi-Agent Productivity Assistant - Final Submission Deck.pptx"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function New-OleColor {
    param([int]$R, [int]$G, [int]$B)
    return [System.Drawing.ColorTranslator]::ToOle([System.Drawing.Color]::FromArgb($R, $G, $B))
}

function Get-ShapeByName {
    param($Slide, [string]$Name)
    foreach ($shape in $Slide.Shapes) {
        if ($shape.Name -eq $Name) {
            return $shape
        }
    }
    throw "Shape '$Name' not found on slide $($Slide.SlideIndex)."
}

function Remove-ShapeIfExists {
    param($Slide, [string]$Name)
    foreach ($shape in @($Slide.Shapes)) {
        if ($shape.Name -eq $Name) {
            $shape.Delete()
            return
        }
    }
}

function Set-ShapeText {
    param(
        $Shape,
        [string]$Text,
        [double]$FontSize = 16,
        [bool]$Bold = $false,
        [int]$FontColor = 0,
        [int]$Alignment = 1
    )

    $Shape.TextFrame.TextRange.Text = $Text
    $Shape.TextFrame.TextRange.Font.Name = "Aptos"
    $Shape.TextFrame.TextRange.Font.Size = $FontSize
    $Shape.TextFrame.TextRange.Font.Bold = $(if ($Bold) { -1 } else { 0 })
    $Shape.TextFrame.TextRange.Font.Color.RGB = $FontColor
    $Shape.TextFrame.TextRange.ParagraphFormat.Alignment = $Alignment
    $Shape.TextFrame.WordWrap = -1
    $Shape.TextFrame.AutoSize = 0
}

function Set-TextByName {
    param(
        $Slide,
        [string]$ShapeName,
        [string]$Text,
        [double]$FontSize = 16,
        [bool]$Bold = $false,
        [int]$FontColor = 0,
        [int]$Alignment = 1
    )

    $shape = Get-ShapeByName -Slide $Slide -Name $ShapeName
    Set-ShapeText -Shape $shape -Text $Text -FontSize $FontSize -Bold $Bold -FontColor $FontColor -Alignment $Alignment
}

function Add-Card {
    param(
        $Slide,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [string]$Text,
        [int]$FillColor,
        [int]$LineColor,
        [double]$FontSize = 14,
        [bool]$Bold = $false,
        [int]$FontColor = 0,
        [int]$ShapeType = 5,
        [int]$Alignment = 1
    )

    $shape = $Slide.Shapes.AddShape($ShapeType, $Left, $Top, $Width, $Height)
    $shape.Fill.Visible = -1
    $shape.Fill.ForeColor.RGB = $FillColor
    $shape.Line.Visible = -1
    $shape.Line.ForeColor.RGB = $LineColor
    $shape.Line.Weight = 1.25
    Set-ShapeText -Shape $shape -Text $Text -FontSize $FontSize -Bold $Bold -FontColor $FontColor -Alignment $Alignment
    return $shape
}

function Add-TextBox {
    param(
        $Slide,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [string]$Text,
        [double]$FontSize = 12,
        [bool]$Bold = $false,
        [int]$FontColor = 0,
        [int]$Alignment = 1
    )

    $shape = $Slide.Shapes.AddTextbox(1, $Left, $Top, $Width, $Height)
    $shape.Line.Visible = 0
    $shape.Fill.Visible = 0
    Set-ShapeText -Shape $shape -Text $Text -FontSize $FontSize -Bold $Bold -FontColor $FontColor -Alignment $Alignment
    return $shape
}

function Add-Arrow {
    param(
        $Slide,
        [int]$X1,
        [int]$Y1,
        [int]$X2,
        [int]$Y2,
        [int]$Color,
        [double]$Weight = 1.75
    )

    $line = $Slide.Shapes.AddConnector(1, $X1, $Y1, $X2, $Y2)
    $line.Line.Visible = -1
    $line.Line.ForeColor.RGB = $Color
    $line.Line.Weight = $Weight
    $line.Line.EndArrowheadStyle = 3
    return $line
}

function Add-PictureFit {
    param(
        $Slide,
        [string]$Path,
        [int]$Left,
        [int]$Top,
        [int]$Width,
        [int]$Height,
        [int]$BorderColor
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing image: $Path"
    }

    $picture = $Slide.Shapes.AddPicture($Path, 0, -1, $Left, $Top, -1, -1)
    $picture.LockAspectRatio = -1
    $scale = [Math]::Min($Width / $picture.Width, $Height / $picture.Height)
    $picture.Width = $picture.Width * $scale
    $picture.Height = $picture.Height * $scale
    $picture.Left = $Left + (($Width - $picture.Width) / 2)
    $picture.Top = $Top + (($Height - $picture.Height) / 2)
    $picture.Line.Visible = -1
    $picture.Line.ForeColor.RGB = $BorderColor
    $picture.Line.Weight = 1
    return $picture
}

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found: $TemplatePath"
}

$outputDirectory = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
Copy-Item -LiteralPath $TemplatePath -Destination $OutputPath -Force

$googleBlue = New-OleColor 66 133 244
$googleGreen = New-OleColor 52 168 83
$googleYellow = New-OleColor 251 188 5
$googleRed = New-OleColor 234 67 53
$deepBlue = New-OleColor 232 240 254
$softBlue = New-OleColor 232 240 254
$softGreen = New-OleColor 230 244 234
$softYellow = New-OleColor 254 247 224
$softRed = New-OleColor 252 232 230
$softGray = New-OleColor 245 247 250
$darkText = New-OleColor 32 33 36
$mutedText = New-OleColor 95 99 104
$outline = New-OleColor 218 220 224
$white = New-OleColor 255 255 255

$ppt = New-Object -ComObject PowerPoint.Application
$ppt.Visible = -1
$presentation = $ppt.Presentations.Open($OutputPath, $false, $false, $false)

try {
    $slide1 = $presentation.Slides.Item(1)
    Set-TextByName -Slide $slide1 -ShapeName "Google Shape;55;p13" -Text @"
Participant Details

Participant Name: Piyush Jayant
Problem Statement: Build a production-ready multi-agent productivity assistant using Google ADK, MCP, AlloyDB AI, BigQuery, and Cloud Run.
"@ -FontSize 17 -Bold $false -FontColor $darkText

    $slide2 = $presentation.Slides.Item(2)
    Set-TextByName -Slide $slide2 -ShapeName "Google Shape;62;p14" -Text @"
Multi-Agent Productivity Assistant is a cloud-native GenAI productivity workspace that unifies tasks, notes, calendar events, and analytics in one conversational experience.

A coordinator agent routes user requests to specialized task, notes, calendar, and analytics agents. AlloyDB AI powers semantic note retrieval, BigQuery powers productivity reporting, and Cloud Run makes the solution publicly deployable for real users and live demos.
"@ -FontSize 17 -FontColor $darkText

    $slide3 = $presentation.Slides.Item(3)
    Set-TextByName -Slide $slide3 -ShapeName "Google Shape;68;p15" -Text @"
We translated the hackathon stack into a working solution by using Google ADK for orchestration, MCP for safe tool access, AlloyDB for operational data, AlloyDB AI for semantic note search, and BigQuery MCP for analytics.

The product solves fragmented personal productivity workflows. Instead of switching between separate task, notes, calendar, and reporting tools, users can manage work from one assistant.

Core workflow: user request -> root coordinator -> specialized agent -> MCP tool execution -> AlloyDB or BigQuery response -> concise user answer. Prototype mode also supports analytics-only demos for faster deployment.
"@ -FontSize 15 -FontColor $darkText

    $slide4 = $presentation.Slides.Item(4)
    Set-TextByName -Slide $slide4 -ShapeName "Google Shape;77;p16" -Text @"
- One assistant handles four productivity jobs instead of isolated point solutions.
- MCP separates reasoning from database access, which improves maintainability and trust.
- AlloyDB AI generates embeddings in-database, reducing extra infrastructure and latency.
- BigQuery analytics turns operational data into measurable productivity insights.
- Cloud Run deployment and prototype mode make the solution demo-ready and scalable.
"@ -FontSize 16 -FontColor $darkText

    $slide5 = $presentation.Slides.Item(5)
    Set-TextByName -Slide $slide5 -ShapeName "Google Shape;84;p17" -Text @"
- Natural-language task management: create, list, update, and delete tasks
- Semantic note search with AlloyDB AI embeddings using text-embedding-005
- Calendar scheduling for events, meetings, and reminders
- Productivity analytics for completion rates, trends, and activity summaries
- Multi-step request handling across multiple specialized agents
- Public Cloud Run deployment with Vertex AI-backed Gemini routing
- Declarative MCP toolbox layer for clean database operations
- Full mode and prototype mode for rich workflows or fast demos
"@ -FontSize 16 -FontColor $darkText

    $slide6 = $presentation.Slides.Item(6)
    Remove-ShapeIfExists -Slide $slide6 -Name "Google Shape;91;p18"
    Add-TextBox -Slide $slide6 -Left 42 -Top 92 -Width 640 -Height 20 -Text "End-to-end workflow from user request to action execution and response." -FontSize 11 -FontColor $mutedText | Out-Null
    Add-Card -Slide $slide6 -Left 38 -Top 130 -Width 95 -Height 42 -Text "User request" -FillColor $deepBlue -LineColor $googleBlue -FontSize 14 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 168 -Top 126 -Width 142 -Height 52 -Text "root_agent`nIntent + routing" -FillColor $softGreen -LineColor $googleGreen -FontSize 15 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 60 -Top 225 -Width 105 -Height 48 -Text "task_agent`nTask CRUD" -FillColor $softYellow -LineColor $googleYellow -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 195 -Top 225 -Width 105 -Height 48 -Text "notes_agent`nSemantic search" -FillColor $softBlue -LineColor $googleBlue -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 330 -Top 225 -Width 120 -Height 48 -Text "calendar_agent`nSchedule events" -FillColor $softGreen -LineColor $googleGreen -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 470 -Top 225 -Width 125 -Height 48 -Text "analytics_agent`nBigQuery insights" -FillColor $softRed -LineColor $googleRed -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide6 -Left 210 -Top 320 -Width 290 -Height 38 -Text "Structured response returned to the user" -FillColor $softGray -LineColor $outline -FontSize 15 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Arrow -Slide $slide6 -X1 133 -Y1 151 -X2 168 -Y2 151 -Color $googleBlue | Out-Null
    Add-Arrow -Slide $slide6 -X1 238 -Y1 178 -X2 112 -Y2 225 -Color $googleGreen | Out-Null
    Add-Arrow -Slide $slide6 -X1 240 -Y1 178 -X2 247 -Y2 225 -Color $googleBlue | Out-Null
    Add-Arrow -Slide $slide6 -X1 244 -Y1 178 -X2 385 -Y2 225 -Color $googleGreen | Out-Null
    Add-Arrow -Slide $slide6 -X1 246 -Y1 178 -X2 532 -Y2 225 -Color $googleRed | Out-Null
    Add-Arrow -Slide $slide6 -X1 112 -Y1 273 -X2 250 -Y2 320 -Color $googleYellow | Out-Null
    Add-Arrow -Slide $slide6 -X1 247 -Y1 273 -X2 300 -Y2 320 -Color $googleBlue | Out-Null
    Add-Arrow -Slide $slide6 -X1 385 -Y1 273 -X2 355 -Y2 320 -Color $googleGreen | Out-Null
    Add-Arrow -Slide $slide6 -X1 532 -Y1 273 -X2 455 -Y2 320 -Color $googleRed | Out-Null

    $slide7 = $presentation.Slides.Item(7)
    Remove-ShapeIfExists -Slide $slide7 -Name "Google Shape;98;p19"
    Add-TextBox -Slide $slide7 -Left 42 -Top 92 -Width 640 -Height 18 -Text "Concept wireframe showing the unified assistant experience." -FontSize 11 -FontColor $mutedText | Out-Null
    Add-Card -Slide $slide7 -Left 42 -Top 118 -Width 255 -Height 230 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide7 -Left 60 -Top 136 -Width 220 -Height 24 -Text "Conversation Workspace" -FillColor $deepBlue -LineColor $googleBlue -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide7 -Left 64 -Top 172 -Width 95 -Height 52 -Text "User:`nCreate a high-priority`nreview task for Friday." -FontSize 11 -FontColor $darkText | Out-Null
    Add-Card -Slide $slide7 -Left 162 -Top 174 -Width 102 -Height 42 -Text "Assistant:`nTask created." -FillColor $softGreen -LineColor $googleGreen -FontSize 11 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide7 -Left 64 -Top 238 -Width 200 -Height 74 -Text "Quick actions`n- Add note`n- Schedule meeting`n- Show analytics" -FillColor $softGray -LineColor $outline -FontSize 12 -Bold $false -FontColor $darkText | Out-Null

    Add-Card -Slide $slide7 -Left 325 -Top 118 -Width 165 -Height 104 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide7 -Left 340 -Top 132 -Width 135 -Height 24 -Text "Tasks + Notes" -FillColor $softYellow -LineColor $googleYellow -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide7 -Left 342 -Top 166 -Width 130 -Height 48 -Text "1. Demo rehearsal`n2. Investor FAQ`n3. Notes about presentation" -FontSize 11 -FontColor $darkText | Out-Null

    Add-Card -Slide $slide7 -Left 506 -Top 118 -Width 165 -Height 104 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide7 -Left 521 -Top 132 -Width 135 -Height 24 -Text "Calendar" -FillColor $softGreen -LineColor $googleGreen -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide7 -Left 523 -Top 166 -Width 130 -Height 48 -Text "09 Apr 2:00 PM`nTeam sync`n45 min" -FontSize 11 -FontColor $darkText | Out-Null

    Add-Card -Slide $slide7 -Left 325 -Top 244 -Width 346 -Height 104 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide7 -Left 340 -Top 258 -Width 135 -Height 24 -Text "Analytics Panel" -FillColor $softRed -LineColor $googleRed -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide7 -Left 344 -Top 292 -Width 315 -Height 48 -Text "Weekly completion rate: 78%`nBest day: Tuesday`nMost active category: high-priority tasks" -FontSize 12 -FontColor $darkText | Out-Null

    $slide8 = $presentation.Slides.Item(8)
    Remove-ShapeIfExists -Slide $slide8 -Name "Google Shape;105;p20"
    Add-Card -Slide $slide8 -Left 46 -Top 135 -Width 105 -Height 42 -Text "User / Web UI" -FillColor $deepBlue -LineColor $googleBlue -FontSize 14 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 186 -Top 104 -Width 240 -Height 165 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide8 -Left 202 -Top 118 -Width 208 -Height 26 -Text "Cloud Run: FastAPI + ADK" -FillColor $softBlue -LineColor $googleBlue -FontSize 14 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 205 -Top 154 -Width 92 -Height 34 -Text "root_agent" -FillColor $softGreen -LineColor $googleGreen -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 312 -Top 154 -Width 96 -Height 34 -Text "Gemini 2.5`nFlash" -FillColor $softYellow -LineColor $googleYellow -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 206 -Top 202 -Width 60 -Height 42 -Text "Tasks" -FillColor $softYellow -LineColor $googleYellow -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 274 -Top 202 -Width 60 -Height 42 -Text "Notes" -FillColor $softBlue -LineColor $googleBlue -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 342 -Top 202 -Width 72 -Height 42 -Text "Calendar" -FillColor $softGreen -LineColor $googleGreen -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 423 -Top 202 -Width 86 -Height 42 -Text "Analytics" -FillColor $softRed -LineColor $googleRed -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null

    Add-Card -Slide $slide8 -Left 200 -Top 304 -Width 175 -Height 40 -Text "MCP Toolbox for Databases" -FillColor $softGray -LineColor $outline -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 410 -Top 304 -Width 170 -Height 40 -Text "Hosted BigQuery MCP" -FillColor $softGray -LineColor $outline -FontSize 13 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 178 -Top 356 -Width 205 -Height 28 -Text "AlloyDB + AlloyDB AI + ScaNN" -FillColor $softGreen -LineColor $googleGreen -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-Card -Slide $slide8 -Left 420 -Top 356 -Width 152 -Height 28 -Text "BigQuery analytics" -FillColor $softYellow -LineColor $googleYellow -FontSize 12 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null

    Add-Arrow -Slide $slide8 -X1 151 -Y1 156 -X2 186 -Y2 156 -Color $googleBlue | Out-Null
    Add-Arrow -Slide $slide8 -X1 306 -Y1 244 -X2 288 -Y2 304 -Color $googleGreen | Out-Null
    Add-Arrow -Slide $slide8 -X1 466 -Y1 244 -X2 495 -Y2 304 -Color $googleRed | Out-Null
    Add-Arrow -Slide $slide8 -X1 288 -Y1 344 -X2 280 -Y2 356 -Color $googleGreen | Out-Null
    Add-Arrow -Slide $slide8 -X1 495 -Y1 344 -X2 495 -Y2 356 -Color $googleYellow | Out-Null
    Add-TextBox -Slide $slide8 -Left 48 -Top 96 -Width 118 -Height 30 -Text "Public Cloud Run URL" -FontSize 11 -Bold $true -FontColor $mutedText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide8 -Left 507 -Top 100 -Width 145 -Height 38 -Text "Analytics path bypasses AlloyDB and queries BigQuery directly." -FontSize 10 -FontColor $mutedText | Out-Null

    $slide9 = $presentation.Slides.Item(9)
    Set-TextByName -Slide $slide9 -ShapeName "Google Shape;112;p21" -Text @"
Google ADK
- Multi-agent orchestration with a root coordinator and specialized sub-agents

Gemini 2.5 Flash via Vertex AI
- Fast reasoning, enterprise-friendly access pattern, and Cloud Run compatibility

Cloud Run
- Public deployment endpoint, serverless scaling, and simple demo operations

MCP Toolbox for Databases
- Safe, declarative SQL tools for tasks, notes, and calendar operations

AlloyDB + AlloyDB AI + pgvector / ScaNN
- Operational store plus in-database semantic embeddings and fast similarity search

BigQuery MCP + BigQuery
- Analytics queries over productivity datasets with minimal custom backend code
"@ -FontSize 14 -FontColor $darkText

    $slide10 = $presentation.Slides.Item(10)
    Remove-ShapeIfExists -Slide $slide10 -Name "Google Shape;118;p22"
    Remove-ShapeIfExists -Slide $slide10 -Name "Google Shape;120;p22"
    Add-Card -Slide $slide10 -Left 40 -Top 100 -Width 310 -Height 230 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-Card -Slide $slide10 -Left 370 -Top 100 -Width 310 -Height 230 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-PictureFit -Slide $slide10 -Path "C:\Users\Piyush\workspace\hackhathon\submission_assets\cloudrun-productivity-app.png" -Left 48 -Top 108 -Width 294 -Height 170 -BorderColor $outline | Out-Null
    Add-PictureFit -Slide $slide10 -Path "C:\Users\Piyush\workspace\hackhathon\submission_assets\github-focused.png" -Left 378 -Top 108 -Width 294 -Height 170 -BorderColor $outline | Out-Null
    Add-TextBox -Slide $slide10 -Left 54 -Top 284 -Width 282 -Height 36 -Text "Live Cloud Run deployment`nPublic ADK interface with agent list available" -FontSize 10.5 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null
    Add-TextBox -Slide $slide10 -Left 384 -Top 284 -Width 282 -Height 36 -Text "Public GitHub repository`nREADME documents architecture and services used" -FontSize 10.5 -Bold $true -FontColor $darkText -Alignment 2 | Out-Null

    $slide11 = $presentation.Slides.Item(11)
    $slide11Body = @"
Cloud Run deployment:
https://productivity-assistant-yzgwwb6nzq-uc.a.run.app/dev-ui/?app=productivity_assistant

GitHub repository:
https://github.com/PiyushJayant/hackhathon

Demo video:
Add final public link here after recording the under-3-minute walkthrough.
"@
    Add-Card -Slide $slide11 -Left 84 -Top 70 -Width 552 -Height 40 -Text "Submission Links" -FillColor $googleBlue -LineColor $googleBlue -FontSize 22 -Bold $true -FontColor $white -Alignment 2 | Out-Null
    Add-Card -Slide $slide11 -Left 66 -Top 122 -Width 588 -Height 198 -Text "" -FillColor $white -LineColor $outline -ShapeType 1 | Out-Null
    Add-TextBox -Slide $slide11 -Left 92 -Top 148 -Width 536 -Height 126 -Text $slide11Body -FontSize 16 -FontColor $darkText | Out-Null

    $presentation.Save()
}
finally {
    $presentation.Close()
    $ppt.Quit()
}

Write-Host "Generated submission deck at $OutputPath"
