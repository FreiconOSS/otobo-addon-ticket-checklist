# --
# Copyright (C) 2016 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentChecklistExport;

use strict;
use warnings;

use Kernel::Language qw(Translatable);
use Kernel::System::VariableCheck qw(:all);

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    # get ticket object
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $MainObject      = $Kernel::OM->Get('Kernel::System::Main');
    my $TicketObject    = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject     = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my $StatusObject    = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    my $DEBUG = $ConfigObject->Get('TicketChecklist::Debug');

    my %GetParam;
    for my $Param ( qw/TicketID Type Filter States/ ) {
        $GetParam{$Param} = $ParamObject->GetParam( Param => $Param ) || '';
    }

    $GetParam{Type} = lc $GetParam{Type};

    my %Types = (
        pdf => '_ExportPDF',
        xls => '_ExportXLSX',
        ics => '_ExportICS',
    );

    $GetParam{Type} = 'pdf' if !exists $Types{ $GetParam{Type} };

    if ( $GetParam{Type} eq 'xls' ) {
        eval {
            require Excel::Writer::XLSX;
            1;
        } or do {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Please ask your administrator to install the Perl module Excel::Writer::XLSX!'),
            );
        };
    }
    elsif ( $GetParam{Type} eq 'ics' ) {
        eval {
            require Data::ICal;
            require Data::ICal::Entry::Todo;
            require Date::ICal;
            1;
        } or do {
            return $LayoutObject->ErrorScreen(
                Message => Translatable('Please ask your administrator to install the Perl modules Data::ICal and Date::ICal!'),
            );
        };
    }

    if ( $DEBUG ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => $MainObject->Dump( \%GetParam ),
        );
    }

    # check needed stuff
    if ( $GetParam{TicketID} ) {

        # check permissions
        my $Access = $TicketObject->TicketPermission(
            Type     => 'ro',
            TicketID => $Self->{TicketID},
            UserID   => $Self->{UserID}
        );

        return $LayoutObject->NoPermission( WithHeader => 'yes' ) if !$Access;
    }

    my @ChecklistItems;

    if ( !$GetParam{Filter} ) {
        @ChecklistItems = $ChecklistObject->TicketChecklistTicketGet(
            TicketID => $GetParam{TicketID},
        );
    }

    if ( $GetParam{Filter} eq 'MyTodos' ) {
        my %Opts;
        if ( $GetParam{States} eq 'Open' ) {
            my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
            my %StatusList   = $StatusObject->TicketChecklistStatusList();
            my %ReverseList  = reverse %StatusList;
            my @OpenIDs      = @ReverseList{ @{$OpenStates} };
            $Opts{StateIDs}  = \@OpenIDs;
        }

        if ( $GetParam{TicketID} ) {
            $Opts{TicketIDs} = [ $GetParam{TicketID} ];
        }

        @ChecklistItems = $ChecklistObject->TaskSearch(
            %Opts,
            UserID    => $Self->{UserID},
        );
    }

    if ( $DEBUG ) {
        $LogObject->Log(
            Priority => 'debug',
            Message  => $MainObject->Dump( \@ChecklistItems ),
        );
    }

    my $Method = $Types{ $GetParam{Type} };

    return $Self->$Method(
        %GetParam,
        ChecklistItems => \@ChecklistItems,
    );
}

sub _ExportICS {
    my ($Self, %Param) = @_;

    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $Calendar = Data::ICal->new;

    ITEM:
    for my $Item ( @{ $Param{ChecklistItems} || [] } ) {
        next ITEM if !$Item->{DueDate};

        if ( !$Param{TicketID} ) {
            $Item->{Title} = $Item->{Title} . '(' . $Item->{TicketNumber} . ')';
        }

        my $IsClosed;

        my $DueDate = Date::ICal->new(
            epoch => $TimeObject->TimeStamp2SystemTime( String => $Item->{DueDate} ),
        )->ical;

        my $Todo = Data::ICal::Entry::Todo->new;
        $Todo->add_properties(
            summary   => $Item->{Title} // '',
            comment   => $Item->{Comment} // '',
            due       => $DueDate,
            completed => ( $IsClosed ? 1 : 0 ),
        );

        $Calendar->add_entry( $Todo );
    }

    my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );

    my $Date     = sprintf "%04d-%02d-%02d_%02d-%02d", $Y, $M, $D, $h, $m;
    my $Filename = "TicketChecklist-$Date.ics";

    my %Headers = (
        Filename    => $Filename,
        ContentType => "text/calendar",
    );

    return $LayoutObject->Attachment(
        %Headers,
        Content     => $Calendar->as_string,
        Type        => 'inline',
    );
}

sub _ExportXLSX {
    my ($Self, %Param) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $TimeObject   = $Kernel::OM->Get('Kernel::System::Time');
    my $LogObject    = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    my $UseFullname = $ConfigObject->Get('TicketChecklist::Widget::ShowResponsibleFullname');
    my $Responsible = $UseFullname ? 'ResponsibleFullname' : 'Responsible';

    my @XLSX;

    for my $Item ( @{ $Param{ChecklistItems} || [] } ) {
        $Item->{Priority} = $LayoutObject->{LanguageObject}->Translate( $Item->{Priority} );
        $Item->{Status}   = $LayoutObject->{LanguageObject}->Translate( $Item->{Status} );

        push @XLSX, [
            @{ $Item }{(qw/Position Priority Title DueDate Status/, $Responsible)}
        ];

        if ( !$Param{TicketID} ) {
            push @{ $XLSX[-1] }, $Item->{TicketNumber};
        }
    }

    my @ColTitles = map{ $LayoutObject->{LanguageObject}->Translate( $_ ) } '#', qw/
        Priority
        Title
        DueDate
        State
        Responsible
    /;

    if ( !$Param{TicketID} ) {
        push @ColTitles, $LayoutObject->{LanguageObject}->Translate( 'TicketNumber' ); 
    }

    unshift @XLSX, \@ColTitles;

    open my $FileHandle, '>', \my $Excel;    ## no critic

    if ( !$FileHandle ) {
        $LogObject->Log(
            Priority => 'error',
            Message  => "Failed to open FileHandle: $!",
        );
        return;
    }

    my $Workbook     = Excel::Writer::XLSX->new($FileHandle);
    my $Worksheet    = $Workbook->add_worksheet();
    my $HeaderFormat = $Workbook->add_format(
        bold       => 1,
        num_format => '@',
    );

    # We will try to determine the appropriate length for each column.
    my @ColumnLengths;
    my $Row = 0;
    for my $DataRaw ( @XLSX ) {
        for my $Col ( 0 .. ( scalar @{ $DataRaw // [] } ) - 1 ) {
            my $CellLength = length( $DataRaw->[$Col] ) || 1;
            $CellLength = 30 if ( $CellLength > 30 );
            if ( !defined $ColumnLengths[$Col] || $ColumnLengths[$Col] < $CellLength ) {
                $ColumnLengths[$Col] = $CellLength;
            }
            if ( $Row == 0 ) {
                # Format header nicely if present.
                $Worksheet->write( $Row, $Col, "$DataRaw->[$Col]", $HeaderFormat );
            }
            else {
                # There are major problems with data recognition in Excel. OTRS
                #   ticket numbers will be recognized as numbers, but they are so big that
                #   Excel will (incorrectly) round them. Prevent this by using write_string()
                #   to protect the data. This might trigger formatting notifications in Excel,
                #   but these can be turned off.
                $Worksheet->write_string( $Row, $Col, ( $DataRaw->[$Col] // '' ) . "" );
            }
        }
        $Row++;
    }

    # Now apply column lengths.
    my $Col = 0;
    for my $ColumnLength (@ColumnLengths) {
        $Worksheet->set_column( $Col, $Col, $ColumnLength );
        $Col++;
    }

    $Workbook->close();

    my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );

    my $Date     = sprintf "%04d-%02d-%02d_%02d-%02d", $Y, $M, $D, $h, $m;
    my $Filename = "TicketChecklist-$Date.xlsx";

    my %Headers = (
        Filename    => $Filename,
        ContentType => "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    );

    return $LayoutObject->Attachment(
        %Headers,
        Content     => $Excel,
        Type        => 'inline',
    );
}

sub _ExportPDF {
    my ($Self, %Param) = @_;

    my $TicketObject       = $Kernel::OM->Get('Kernel::System::Ticket');
    my $ParamObject        = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $LayoutObject       = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $ConfigObject       = $Kernel::OM->Get('Kernel::Config');
    my $UserObject         = $Kernel::OM->Get('Kernel::System::User');
    my $CustomerUserObject = $Kernel::OM->Get('Kernel::System::CustomerUser');
    my $PDFObject          = $Kernel::OM->Get('Kernel::System::PDF');
    my $TimeObject         = $Kernel::OM->Get('Kernel::System::Time');

    # get needed objects
    my $PrintedBy = $LayoutObject->{LanguageObject}->Translate('printed by');
    my $Time      = $LayoutObject->{LanguageObject}->FormatTimeString(
        $TimeObject->CurrentTimestamp(),
        'DateFormat',
    );

    my %Page;

    # get maximum number of pages
    $Page{MaxPages} = $ConfigObject->Get('PDF::MaxPages');
    if ( !$Page{MaxPages} || $Page{MaxPages} < 1 || $Page{MaxPages} > 1000 ) {
        $Page{MaxPages} = 100;
    }
    my $HeaderRight  = $LayoutObject->{LanguageObject}->Translate('Checklist');
    my $HeadlineLeft = $HeaderRight;
    my $Title        = $HeaderRight;

    $Page{MarginTop}    = 30;
    $Page{MarginRight}  = 40;
    $Page{MarginBottom} = 40;
    $Page{MarginLeft}   = 40;
    $Page{HeaderRight}  = $HeaderRight;
    $Page{FooterLeft}   = '';
    $Page{PageText}     = $LayoutObject->{LanguageObject}->Translate('Page');
    $Page{PageCount}    = 1;

    my %Ticket;
    my %ResponsibleInfo;
    my %UserInfo;

    if ( $Param{TicketID} ) {

        %Ticket = $TicketObject->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 1,
        );

        my $HeaderRight     = $ConfigObject->Get('Ticket::Hook') . $Ticket{TicketNumber};
        $Page{HeaderRight}  = $HeaderRight;

        if ( $Ticket{Title} ) {
            $HeadlineLeft = $Ticket{Title};
            $Title .= ' / ' . $Ticket{Title};
        }

        # user info
        %UserInfo = $UserObject->GetUserData(
            User => $Ticket{Owner},
        );

        # responsible info
        if ( $ConfigObject->Get('Ticket::Responsible') && $Ticket{Responsible} ) {
            %ResponsibleInfo = $UserObject->GetUserData(
                User => $Ticket{Responsible},
            );
        }

        # do some html quoting
        $Ticket{Age} = $LayoutObject->CustomerAge(
            Age   => $Ticket{Age},
            Space => ' ',
        );

        if ( $Ticket{UntilTime} ) {
            $Ticket{PendingUntil} = $LayoutObject->CustomerAge(
                Age   => $Ticket{UntilTime},
                Space => ' ',
            );
        }
    }

    # create new pdf document
    $PDFObject->DocumentNew(
        Title  => $ConfigObject->Get('Product') . ': ' . $Title,
        Encode => $LayoutObject->{UserCharset},
    );

    # create first pdf page
    $PDFObject->PageNew(
        %Page,
        FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
    );
    $Page{PageCount}++;

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -6,
    );

    # output "printed by"
    $PDFObject->Text(
        Text => $PrintedBy . ' '
            . $Self->{UserFirstname} . ' '
            . $Self->{UserLastname} . ' ('
            . $Self->{UserEmail} . ')'
            . ', ' . $Time,
        FontSize => 9,
    );

    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -14,
    );

    if ( %Ticket ) {

        # output ticket infos
        $Self->_PDFOutputTicketInfos(
            PageData        => \%Page,
            TicketData      => \%Ticket,
            UserData        => \%UserInfo,
            ResponsibleData => \%ResponsibleInfo,
        );

        $PDFObject->PositionSet(
            Move => 'relativ',
            Y    => -6,
        );
    }

    $Self->_PDFOutputChecklist(
        PageData => \%Page,
        Items    => $Param{ChecklistItems},
    );

    # get time object and use the UserTimeObject, if the system use UTC as
    # system time and the TimeZoneUser feature is active
    if (
        !$TimeObject->ServerLocalTimeOffsetSeconds()
        && $ConfigObject->Get('TimeZoneUser')
        && $Self->{UserTimeZone}
        )
    {
        $TimeObject = $LayoutObject->{UserTimeObject};
    }

    # return the pdf document
    my $Filename = 'Ticket_' . $Ticket{TicketNumber};
    my ( $s, $m, $h, $D, $M, $Y ) = $TimeObject->SystemTime2Date(
        SystemTime => $TimeObject->SystemTime(),
    );
    $M = sprintf( "%02d", $M );
    $D = sprintf( "%02d", $D );
    $h = sprintf( "%02d", $h );
    $m = sprintf( "%02d", $m );

    my $PDFString = $PDFObject->DocumentOutput();

    return $LayoutObject->Attachment(
        Filename    => $Filename . "_" . "$Y-$M-$D" . "_" . "$h-$m.pdf",
        ContentType => "application/pdf",
        Content     => $PDFString,
        Type        => 'inline',
    );
}

sub _PDFOutputChecklist {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LogObject       = $Kernel::OM->Get('Kernel::System::Log');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    for my $Needed (qw(PageData Items)) {
        if ( !defined( $Param{$Needed} ) ) {
            $LogObject->Log(
                Priority => 'error',
                Message  => "Need $Needed!",
            );
            return;
        }
    }

    my %Page = %{ $Param{PageData} };

    my %TableParam;
    my $Row = 0;

    my @ChecklistItems = @{ $Param{Items} || [] };

    return if !@ChecklistItems;

    my $PrintComment = $ConfigObject->Get('TicketChecklist::PrintItemComment');

    my $UseFullname = $ConfigObject->Get('TicketChecklist::Widget::ShowResponsibleFullname');
    my $Responsible = $UseFullname ? 'ResponsibleFullname' : 'Responsible';

    for my $Item ( @ChecklistItems ) {
        $TableParam{CellData}[$Row][0]{Content} = $Item->{Position} || '';
        $TableParam{CellData}[$Row][1]{Content} = $LayoutObject->{LanguageObject}->Translate( $Item->{Priority} || '' );
        $TableParam{CellData}[$Row][2]{Content} = $Item->{Title} || '';
        $TableParam{CellData}[$Row][3]{Content} = $LayoutObject->{LanguageObject}->Translate( $Item->{Status} || '' );
        $TableParam{CellData}[$Row][4]{Content} = $Item->{$Responsible} || '';

        my $Time = $LayoutObject->{LanguageObject}->FormatTimeString(
            $Item->{DueDate},
            'DateFormat',
        );

        $TableParam{CellData}[$Row][5]{Content} = $Time;

        if ( !$Param{TicketID} ) {
            $TableParam{CellData}[$Row][6]{Content} = $Item->{TicketNumber};
        }

        $Row++;

        if ( $PrintComment && defined $Item->{Comment} && $Item->{Comment} ne '' ) {
            $TableParam{CellData}[$Row][0]{Content} = '';
            $TableParam{CellData}[$Row][1]{Content} = '';
            $TableParam{CellData}[$Row][2]{Content} = $Item->{Comment} // '';
            $Row++;
        }
    }

    $TableParam{ColumnData}[0]{Width} = 8;
    $TableParam{ColumnData}[1]{Width} = 30;
    $TableParam{ColumnData}[2]{Width} = 200;
    $TableParam{ColumnData}[3]{Width} = 45;
    $TableParam{ColumnData}[4]{Width} = 80;
    $TableParam{ColumnData}[5]{Width} = 60;

    # get PDF object
    my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

    $PDFObject->HLine(
        Color     => '#aaa',
        LineWidth => 0.5,
    );

    # set new position
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -10,
    );

    # output headline
    $PDFObject->Text(
        Text     => $LayoutObject->{LanguageObject}->Translate('Checklist'),
        Height   => 10,
        Type     => 'Cut',
        Font     => 'Proportional',
        FontSize => 9,
        Color    => '#666666',
    );

    # set new position
    $PDFObject->PositionSet(
        Move => 'relativ',
        Y    => -4,
    );

    # table params
    $TableParam{Type}                = 'Cut';
    $TableParam{Border}              = 0;
    $TableParam{FontSize}            = 6;
    $TableParam{Padding}             = 1;
    $TableParam{PaddingTop}          = 3;
    $TableParam{PaddingBottom}       = 3;
    $TableParam{BackgroundColorEven} = '#F2F2F2';


    # output table
    PAGE:
    for ( $Page{PageCount} .. $Page{MaxPages} ) {

        # output table (or a fragment of it)
        %TableParam = $PDFObject->Table( %TableParam, );

        # stop output or output next page
        if ( $TableParam{State} ) {
            last PAGE;
        }
        else {
            $PDFObject->PageNew(
                %Page,
                FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
            );
            $Page{PageCount}++;
        }
    }

    return 1;
}

sub _PDFOutputTicketInfos {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for my $Needed (qw(PageData TicketData UserData)) {
        if ( !defined( $Param{$Needed} ) ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $Needed!"
            );
            return;
        }
    }
    my %Ticket   = %{ $Param{TicketData} };
    my %UserInfo = %{ $Param{UserData} };
    my %Page     = %{ $Param{PageData} };

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # create left table
    my $TableLeft = [
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('State'),
            Value => $LayoutObject->{LanguageObject}->Translate( $Ticket{State} ),
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Priority'),
            Value => $LayoutObject->{LanguageObject}->Translate( $Ticket{Priority} ),
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Queue'),
            Value => $Ticket{Queue},
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Lock'),
            Value => $LayoutObject->{LanguageObject}->Translate( $Ticket{Lock} ),
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('CustomerID'),
            Value => $Ticket{CustomerID},
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Owner'),
            Value => $Ticket{Owner} . ' ('
                . $UserInfo{UserFirstname} . ' '
                . $UserInfo{UserLastname} . ')',
        },
    ];

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # add responsible row, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Responsible') ) {
        my $Responsible = '-';
        if ( $Ticket{Responsible} ) {
            $Responsible = $Ticket{Responsible} . ' ('
                . $Param{ResponsibleData}->{UserFirstname} . ' '
                . $Param{ResponsibleData}->{UserLastname} . ')';
        }
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Responsible'),
            Value => $Responsible,
        };
        push( @{$TableLeft}, $Row );
    }

    # add type row, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Type') ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Type'),
            Value => $Ticket{Type},
        };
        push( @{$TableLeft}, $Row );
    }

    # add service and sla row, if feature is enabled
    if ( $ConfigObject->Get('Ticket::Service') ) {
        my $RowService = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Service'),
            Value => $Ticket{Service} || '-',
        };
        push( @{$TableLeft}, $RowService );
        my $RowSLA = {
            Key   => $LayoutObject->{LanguageObject}->Translate('SLA'),
            Value => $Ticket{SLA} || '-',
        };
        push( @{$TableLeft}, $RowSLA );
    }

    # create right table
    my $TableRight = [
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Age'),
            Value => $LayoutObject->{LanguageObject}->Translate( $Ticket{Age} ),
        },
        {
            Key   => $LayoutObject->{LanguageObject}->Translate('Created'),
            Value => $LayoutObject->{LanguageObject}->FormatTimeString(
                $Ticket{Created},
                'DateFormat',
            ),
        },
    ];

    # show created by if different then User ID 1
    if ( $Ticket{CreateBy} > 1 ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Created by'),
            Value => $Kernel::OM->Get('Kernel::System::User')->UserName( UserID => $Ticket{CreateBy} ),
        };
        push( @{$TableRight}, $Row );
    }

    # only show pending until unless it is really pending
    if ( $Ticket{PendingUntil} ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Pending till'),
            Value => $Ticket{PendingUntil},
        };
        push( @{$TableRight}, $Row );
    }

    # add first response time row
    if ( defined( $Ticket{FirstResponseTime} ) ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('First Response Time'),
            Value => $LayoutObject->{LanguageObject}->FormatTimeString(
                $Ticket{FirstResponseTimeDestinationDate},
                'DateFormat',
                'NoSeconds',
            ),
        };
        push( @{$TableRight}, $Row );
    }

    # add update time row
    if ( defined( $Ticket{UpdateTime} ) ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Update Time'),
            Value => $LayoutObject->{LanguageObject}->FormatTimeString(
                $Ticket{UpdateTimeDestinationDate},
                'DateFormat',
                'NoSeconds',
            ),
        };
        push( @{$TableRight}, $Row );
    }

    # add solution time row
    if ( defined( $Ticket{SolutionTime} ) ) {
        my $Row = {
            Key   => $LayoutObject->{LanguageObject}->Translate('Solution Time'),
            Value => $LayoutObject->{LanguageObject}->FormatTimeString(
                $Ticket{SolutionTimeDestinationDate},
                'DateFormat',
                'NoSeconds',
            ),
        };
        push( @{$TableRight}, $Row );
    }

    my $Rows = @{$TableLeft};
    if ( @{$TableRight} > $Rows ) {
        $Rows = @{$TableRight};
    }

    my %TableParam;
    for my $Row ( 1 .. $Rows ) {
        $Row--;
        $TableParam{CellData}[$Row][0]{Content}         = $TableLeft->[$Row]->{Key};
        $TableParam{CellData}[$Row][0]{Font}            = 'ProportionalBold';
        $TableParam{CellData}[$Row][1]{Content}         = $TableLeft->[$Row]->{Value};
        $TableParam{CellData}[$Row][2]{Content}         = ' ';
        $TableParam{CellData}[$Row][2]{BackgroundColor} = '#FFFFFF';
        $TableParam{CellData}[$Row][3]{Content}         = $TableRight->[$Row]->{Key};
        $TableParam{CellData}[$Row][3]{Font}            = 'ProportionalBold';
        $TableParam{CellData}[$Row][4]{Content}         = $TableRight->[$Row]->{Value};
    }

    $TableParam{ColumnData}[0]{Width} = 70;
    $TableParam{ColumnData}[1]{Width} = 156.5;
    $TableParam{ColumnData}[2]{Width} = 1;
    $TableParam{ColumnData}[3]{Width} = 70;
    $TableParam{ColumnData}[4]{Width} = 156.5;

    $TableParam{Type}                = 'Cut';
    $TableParam{Border}              = 0;
    $TableParam{FontSize}            = 7;
    $TableParam{BackgroundColorEven} = '#F2F2F2';
    $TableParam{Padding}             = 6;
    $TableParam{PaddingTop}          = 3;
    $TableParam{PaddingBottom}       = 3;

    # output table
    PAGE:
    for ( $Page{PageCount} .. $Page{MaxPages} ) {

        # get PDF object
        my $PDFObject = $Kernel::OM->Get('Kernel::System::PDF');

        # output table (or a fragment of it)
        %TableParam = $PDFObject->Table( %TableParam, );

        # stop output or output next page
        if ( $TableParam{State} ) {
            last PAGE;
        }
        else {
            $PDFObject->PageNew(
                %Page,
                FooterRight => $Page{PageText} . ' ' . $Page{PageCount},
            );
            $Page{PageCount}++;
        }
    }
    return 1;
}

1;
