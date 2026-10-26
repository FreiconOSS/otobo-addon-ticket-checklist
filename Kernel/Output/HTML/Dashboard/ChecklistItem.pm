# --
# Copyright (C) 2015 - 2022 Perl-Services.de, https://www.perl-services.de
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Output::HTML::Dashboard::ChecklistItem;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);

our @ObjectDependencies = qw(
    Kernel::Config
    Kernel::Language
    Kernel::System::Cache
    Kernel::System::JSON
    Kernel::System::User
    Kernel::System::Web::Request
    Kernel::System::Priority
    Kernel::Output::HTML::Layout
    Kernel::System::AuthSession
    Kernel::System::PerlServices::TicketChecklist
    Kernel::System::PerlServices::TicketChecklistStatus
);

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $JSONObject    = $Kernel::OM->Get('Kernel::System::JSON');
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $LayoutObject  = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');

    # define filterable columns
    $Self->{ValidFilterableColumns} = {
        'Status'      => '_GetStates',
        'Priority'    => '_GetPriorities',
        'ChangeAgent' => '_GetUsers',
    };

    my $RemoveFilters = $ParamObject->GetParam( Param => 'RemoveFilters' )
        || $Param{RemoveFilters}
        || 0;

    # get sorting params
    for my $Item (qw(SortBy OrderBy Name)) {
        $Self->{$Item} = $ParamObject->GetParam( Param => $Item ) || $Param{$Item};
    }

    # set filter settings
    for my $Item (qw(ColumnFilter GetColumnFilter GetColumnFilterSelect)) {
        $Self->{$Item} = $Param{$Item} || {};
    }

    if ( !%{ $Self->{GetColumnFilter} || {} } ) {

        COLUMN:
        for my $Column ( sort keys %{ $Self->{ValidFilterableColumns} || {} } ) {
            my $LongName = 'ColumnFilter' . $Column . $Self->{Name};
            my $Value    = $ParamObject->GetParam( Param => $LongName );

            next COLUMN if !$Value;

            $Self->{GetColumnFilter}->{ $Column . $Self->{Name} } = $Value;
            $Self->{GetColumnFilterSelect}->{$Column}             = $Value;
            $Self->{ColumnFilter}->{ $Column . 'IDs' }            = [$Value];
        }
    }

    # save column filters
    $Self->{PrefKeyColumnFilters}         = 'UserDashboardChecklistItemColumnFilters' . $Self->{Name};
    $Self->{PrefKeyColumnFiltersRealKeys} = 'UserDashboardChecklistItemColumnFiltersRealKeys' . $Self->{Name};

    if ($RemoveFilters) {
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{PrefKeyColumnFilters},
            Value  => '',
        );
        $UserObject->SetPreferences(
            UserID => $Self->{UserID},
            Key    => $Self->{PrefKeyColumnFiltersRealKeys},
            Value  => '',
        );
    }

    # just in case new filter values arrive
    elsif (
        IsHashRefWithData( $Self->{GetColumnFilter} )
        && IsHashRefWithData( $Self->{GetColumnFilterSelect} )
        && IsHashRefWithData( $Self->{ColumnFilter} )
        )
    {

        if ( !$ConfigObject->Get('DemoSystem') ) {

            # check if the user has filter preferences for this widget
            my %Preferences = $UserObject->GetPreferences(
                UserID => $Self->{UserID},
            );
            my $ColumnPrefValues;
            if ( $Preferences{ $Self->{PrefKeyColumnFilters} } ) {
                $ColumnPrefValues = $JSONObject->Decode(
                    Data => $Preferences{ $Self->{PrefKeyColumnFilters} },
                );
            }

            PREFVALUES:
            for my $Column ( sort keys %{ $Self->{GetColumnFilterSelect} } ) {
                if ( $Self->{GetColumnFilterSelect}->{$Column} eq 'DeleteFilter' ) {
                    delete $ColumnPrefValues->{$Column};
                    next PREFVALUES;
                }
                $ColumnPrefValues->{$Column} = $Self->{GetColumnFilterSelect}->{$Column};
            }

            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Self->{PrefKeyColumnFilters},
                Value  => $JSONObject->Encode( Data => $ColumnPrefValues ),
            );

            # save real key's name
            my $ColumnPrefRealKeysValues;
            if ( $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} } ) {
                $ColumnPrefRealKeysValues = $JSONObject->Decode(
                    Data => $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} },
                );
            }
            REALKEYVALUES:
            for my $Column ( sort keys %{ $Self->{ColumnFilter} } ) {
                next REALKEYVALUES if !$Column;

                my $DeleteFilter = 0;
                if ( IsArrayRefWithData( $Self->{ColumnFilter}->{$Column} ) ) {
                    if ( grep { $_ eq 'DeleteFilter' } @{ $Self->{ColumnFilter}->{$Column} } ) {
                        $DeleteFilter = 1;
                    }
                }
                elsif ( IsHashRefWithData( $Self->{ColumnFilter}->{$Column} ) ) {

                    if (
                        grep { $Self->{ColumnFilter}->{$Column}->{$_} eq 'DeleteFilter' }
                        keys %{ $Self->{ColumnFilter}->{$Column} }
                        )
                    {
                        $DeleteFilter = 1;
                    }
                }

                if ($DeleteFilter) {
                    delete $ColumnPrefRealKeysValues->{$Column};
                    delete $Self->{ColumnFilter}->{$Column};
                    next REALKEYVALUES;
                }
                $ColumnPrefRealKeysValues->{$Column} = $Self->{ColumnFilter}->{$Column};
            }
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Self->{PrefKeyColumnFiltersRealKeys},
                Value  => $JSONObject->Encode( Data => $ColumnPrefRealKeysValues ),
            );

        }
    }

    # check if the user has filter preferences for this widget
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    # get column names from Preferences
    my $PreferencesColumnFilters;
    if ( $Preferences{ $Self->{PrefKeyColumnFilters} } ) {
        $PreferencesColumnFilters = $JSONObject->Decode(
            Data => $Preferences{ $Self->{PrefKeyColumnFilters} },
        );
    }

    if ($PreferencesColumnFilters) {
        $Self->{GetColumnFilterSelect} = $PreferencesColumnFilters;
        my @ColumnFilters = keys %{$PreferencesColumnFilters};    ## no critic
        for my $Field (@ColumnFilters) {
            $Self->{GetColumnFilter}->{ $Field . $Self->{Name} } = $PreferencesColumnFilters->{$Field};
        }
    }

    # get column real names from Preferences
    my $PreferencesColumnFiltersRealKeys;
    if ( $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} } ) {
        $PreferencesColumnFiltersRealKeys = $JSONObject->Decode(
            Data => $Preferences{ $Self->{PrefKeyColumnFiltersRealKeys} },
        );
    }

    if ($PreferencesColumnFiltersRealKeys) {
        my @ColumnFiltersReal = keys %{$PreferencesColumnFiltersRealKeys};    ## no critic
        for my $Field (@ColumnFiltersReal) {
            $Self->{ColumnFilter}->{$Field} = $PreferencesColumnFiltersRealKeys->{$Field};
        }
    }

    # get current filter
    my $Name = $ParamObject->GetParam( Param => 'Name' ) || '';
    my $PreferencesKey = 'UserDashboardChecklistItemFilter' . $Self->{Name};
    if ( $Self->{Name} eq $Name ) {
        $Self->{Filter} = $ParamObject->GetParam( Param => 'Filter' ) || '';
    }

    # remember filter
    if ( $Self->{Filter} ) {

        # update session
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $PreferencesKey,
            Value     => $Self->{Filter},
        );

        # update preferences
        if ( !$ConfigObject->Get('DemoSystem') ) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $PreferencesKey,
                Value  => $Self->{Filter},
            );
        }
    }
    else {
        $Self->{Filter} = $Self->{$PreferencesKey} || $Self->{Config}->{Filter} || 'All';
    }

    $Self->{PrefKeyShown}   = 'UserDashboardPref' . $Self->{Name} . '-Shown';
    $Self->{PageShown}      = $LayoutObject->{ $Self->{PrefKeyShown} }
        || $Self->{Config}->{Limit};

    $Self->{StartHit} = int( $ParamObject->GetParam( Param => 'StartHit' ) || 1 );

    $Self->{PrefKeyShowChangeStateAgent}   = 'UserDashboardPref' . $Self->{Name} . '-ShowStateChangeAgent';
    $Self->{ShowStateChangeAgent} = $LayoutObject->{ $Self->{PrefKeyShowChangeStateAgent} }
        || 0;

    # hash with all valid sortable columuns
    $Self->{ValidSortableColumns} = {
        'Title'        => 1,
        'Status'       => 1,
        'Priority'     => 1,
        'DueDate'      => 1,
        'DateStart'    => 1,
        'TicketNumber' => 1,
        'ChangeAgent'  => 1,
    };

    return $Self;
}

sub Preferences {
    my ( $Self, %Param ) = @_;

    my $UserObject = $Kernel::OM->Get('Kernel::System::User');

    # check if the user has filter preferences for this widget
    my %Preferences = $UserObject->GetPreferences(
        UserID => $Self->{UserID},
    );

    my @Params = (
        {
            Desc  => 'Shown Items',
            Name  => $Self->{PrefKeyShown},
            Block => 'Option',
            Data  => {
                5  => ' 5',
                10 => '10',
                15 => '15',
                20 => '20',
                25 => '25',
                30 => '30',
                40 => '40',
                50 => '50',
                75 => '75',
            },
            SelectedID  => $Self->{PageShown},
            Translation => 0,
        },
        {
            Desc  => 'Show Agent who changed the state',
            Name  => $Self->{PrefKeyShowChangeStateAgent},
            Block => 'Option',
            Data  => {
                0 => 'No',
                1 => 'Yes',
            },
            SelectedID  => $Self->{ShowStateChangeAgent},
            Translation => 1,
        },
    );

    return @Params;
}

sub Config {
    my ( $Self, %Param ) = @_;

    return (
        %{ $Self->{Config} },

        # remember, do not allow to use page cache
        # (it's not working because of internal filter)
        CacheTTL => undef,
        CacheKey => undef,
    );
}

sub FilterContent {
    my ( $Self, %Param ) = @_;

    return if !$Param{FilterColumn};

    my $HeaderColumn = $Param{FilterColumn};

    # get column values for to build the filters later
    my %ColumnValues;

    COLUMN:
    for my $Column ( keys %{ $Self->{ValidFilterableColumns} || {} } ) {
        next COLUMN if $Self->{ValidFilterableColumns}->{$Column} eq 1;

        my $Method             = $Self->{ValidFilterableColumns}->{$Column};
        $ColumnValues{$Column} = +{ $Self->$Method() };
    }

    my $SelectedValue = defined $Self->{GetColumnFilter}->{ $HeaderColumn . $Self->{Name} }
        ? $Self->{GetColumnFilter}->{ $HeaderColumn . $Self->{Name} }
        : '';

    # variable to save the filter's html code
    my $ColumnFilterJSON = $Self->_ColumnFilterJSON(
        ColumnName    => $HeaderColumn,
        Label         => $HeaderColumn,
        ColumnValues  => $ColumnValues{$HeaderColumn} || '',
        SelectedValue => $SelectedValue,
        DashboardName => $Self->{Name},
    );

    return $ColumnFilterJSON;

}

sub Run {
    my ( $Self, %Param ) = @_;

    my $ConfigObject    = $Kernel::OM->Get('Kernel::Config');
    my $LanguageObject  = $Kernel::OM->Get('Kernel::Language');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');
    my $CacheObject     = $Kernel::OM->Get('Kernel::System::Cache');
    my $UserObject      = $Kernel::OM->Get('Kernel::System::User');
    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');

    my %SearchParams;

    my $CacheKey = $Self->{Name} . '-'
        . $Self->{Action} . '-'
        . $Self->{PageShown} . '-'
        . $Self->{StartHit} . '-'
        . $Self->{UserID};
    my $CacheColumns = join(
        ',',
        map {
            $_ . '=>' . $Self->{GetColumnFilterSelect}->{$_}
        } sort keys %{ $Self->{GetColumnFilterSelect} }
    );

    $CacheKey .= '-' . $CacheColumns if $CacheColumns;

    $CacheKey .= '-' . $Self->{SortBy}  if defined $Self->{SortBy};
    $CacheKey .= '-' . $Self->{OrderBy} if defined $Self->{OrderBy};

    # check cache
    my $Items = $CacheObject->Get(
        Type => 'Dashboard',
        Key  => $CacheKey . '-' . $Self->{Filter} . '-List',
    );

    my $CacheUsed = 1;

    if ( !$Items ) {

        $CacheUsed = 0;

        # add sort by parameter to the search
        if ( $Self->{SortBy} && $Self->{ValidSortableColumns}->{ $Self->{SortBy} } ) {
            $SearchParams{SortBy} = $Self->{SortBy};
        }
        else {
            $SearchParams{SortBy} = 'DueDate';
        }

        # add order by parameter to the search
        if ( $Self->{OrderBy} ) {
            $SearchParams{OrderBy} = $Self->{OrderBy};
        }

        my @Items = $ChecklistObject->TaskSearch(
            %SearchParams,
            %{ $Self->{ColumnFilter} },
            Types  => 'open',
            #Limit => $Self->{PageShown} + $Self->{StartHit} - 1,
            UserID => $Self->{UserID},
        );

        $Items = \@Items;
    }

    if ( !$CacheUsed && $Self->{Config}->{CacheTTLLocal} ) {
        $CacheObject->Set(
            Type  => 'Dashboard',
            Key   => $CacheKey . '-' . $Self->{Filter} . '-List',
            Value => $Items,
            TTL   => $Self->{Config}->{CacheTTLLocal} * 60,
        );
    }

    # add page nav bar
    my $Total = @{ $Items || [] };

    my $Start = $Self->{StartHit} - 1;
    my $Stop  = $Self->{PageShown} + $Self->{StartHit} - 2;

    if ( $Stop > $#$Items ) {
        $Stop = $#$Items;
    }

    $Items = [ @{ $Items }[ $Start .. $Stop ] ];

    my %GetColumnFilter = $Self->{GetColumnFilter} ? %{ $Self->{GetColumnFilter} } : ();

    my $ColumnFilterLink = '';
    COLUMNNAME:
    for my $ColumnName ( sort keys %GetColumnFilter ) {
        next COLUMNNAME if !$ColumnName;
        next COLUMNNAME if !$GetColumnFilter{$ColumnName};
        $ColumnFilterLink
            .= ';' . $LayoutObject->Ascii2Html( Text => 'ColumnFilter' . $ColumnName )
            . '=' . $LayoutObject->Ascii2Html( Text => $GetColumnFilter{$ColumnName} )
    }

    my $LinkPage =
        'Subaction=Element;Name=' . $Self->{Name}
        . ';Filter=' . $Self->{Filter}
        . ';SortBy=' .  ( $Self->{SortBy}  || '' )
        . ';OrderBy=' . ( $Self->{OrderBy} || '' )
        . $ColumnFilterLink
        . ';';

    my %PageNav = $LayoutObject->PageNavBar(
        StartHit       => $Self->{StartHit},
        PageShown      => $Self->{PageShown},
        AllHits        => $Total || 1,
        Action         => 'Action=' . $LayoutObject->{Action},
        Link           => $LinkPage,
        AJAXReplace    => 'Dashboard' . $Self->{Name},
        IDPrefix       => 'Dashboard' . $Self->{Name},
        KeepScriptTags => $Param{AJAX},
    );

    $LayoutObject->Block(
        Name => 'ContentLargeChecklistItemFilterNavBar',
        Data => {
            %{ $Self->{Config} },
            Name => $Self->{Name},
            %PageNav,
        },
    );

    # show table header
    $LayoutObject->Block(
        Name => 'ContentLargeChecklistItemHeader',
        Data => {},
    );

    # show non-labeled table headers
    my $CSS = '';
    my $OrderBy;

    my @Columns = qw(
        Title DueDate Priority Status TicketNumber TicketTitle
    );

    if ( $ConfigObject->Get('TicketChecklist::Feature::DateStart') ) {
        splice @Columns, 1, 0, 'DateStart';
    }

    if ( $Self->{ShowStateChangeAgent} ) {
        splice @Columns, 4, 0, 'ChangeAgent';
    }

    # show all needed headers
    HEADERCOLUMN:
    for my $HeaderColumn (@Columns) {

        $CSS = '';
        my $Title = $HeaderColumn;

        if ( $Self->{SortBy} && ( $Self->{SortBy} eq $HeaderColumn ) ) {
            if ( $Self->{OrderBy} && ( $Self->{OrderBy} eq 'Up' ) ) {
                $OrderBy = 'Down';
                $CSS .= ' SortDescendingLarge';
            }
            else {
                $OrderBy = 'Up';
                $CSS .= ' SortAscendingLarge';
            }

            # add title description
            my $TitleDesc = $OrderBy eq 'Down' ? 'sorted descending' : 'sorted ascending';
            $TitleDesc = $LanguageObject->Translate($TitleDesc);
            $Title .= ', ' . $TitleDesc;
        }

        my $TranslatedWord = $LanguageObject->Translate($HeaderColumn);

        # add surrounding container
        $LayoutObject->Block(
            Name => 'GeneralOverviewHeader',
        );
        $LayoutObject->Block(
            Name => 'ContentLargeChecklistItemHeaderTicketHeader',
            Data => {},
        );

        my $FilterTitle     = $HeaderColumn;
        my $FilterTitleDesc = 'filter not active';
        if ( $Self->{GetColumnFilterSelect} && $Self->{GetColumnFilterSelect}->{$HeaderColumn} )
        {
            $CSS .= ' FilterActive';
            $FilterTitleDesc = 'filter active';
        }
        $FilterTitleDesc = $LanguageObject->Translate($FilterTitleDesc);
        $FilterTitle .= ', ' . $FilterTitleDesc;

        if ( $HeaderColumn eq 'TicketNumber' ) {
            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderTicketNumberColumn',
                Data => {
                    HeaderColumnName     => $HeaderColumn   || '',
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    CSS                  => $CSS            || '',
                    OrderBy              => $OrderBy || 'Up',
                    SortBy               => $Self->{SortBy} || $HeaderColumn,
                    Name                 => $Self->{Name},
                    Title                => $Title,
                },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderColumn',
                Data => {
                    HeaderColumnName     => $HeaderColumn   || '',
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    CSS                  => $CSS            || '',
                },
            );
        }

        # verify if column is filterable and sortable
        if (
            $Self->{ValidSortableColumns}->{$HeaderColumn}
            && $Self->{ValidFilterableColumns}->{$HeaderColumn}
            )
        {

            # variable to save the filter's html code
            my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                ColumnName => $HeaderColumn,
                Items      => $Items,
            );

            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderColumnFilterLink',
                Data => {
                    %Param,
                    HeaderColumnName     => $HeaderColumn,
                    CSS                  => $CSS,
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    ColumnFilterStrg     => $ColumnFilterHTML,
                    OrderBy              => $OrderBy || 'Up',
                    SortBy               => $Self->{SortBy} || 'Age',
                    Name                 => $Self->{Name},
                    Title                => $Title,
                    FilterTitle          => $FilterTitle,
                },
            );
        }

        # verify if column is just filterable
        elsif ( $Self->{ValidFilterableColumns}->{$HeaderColumn} ) {

            # variable to save the filter's html code
            my $ColumnFilterHTML = $Self->_InitialColumnFilter(
                ColumnName => $HeaderColumn,
                Items      => $Items,
            );

            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderColumnFilter',
                Data => {
                    %Param,
                    HeaderColumnName     => $HeaderColumn,
                    CSS                  => $CSS,
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    ColumnFilterStrg     => $ColumnFilterHTML,
                    Name                 => $Self->{Name},
                    Title                => $Title,
                    FilterTitle          => $FilterTitle,
                },
            );
        }

        # verify if column is just sortable
        elsif ( $Self->{ValidSortableColumns}->{$HeaderColumn} ) {
            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderColumnLink',
                Data => {
                    %Param,
                    HeaderColumnName     => $HeaderColumn,
                    CSS                  => $CSS,
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    OrderBy              => $OrderBy || 'Up',
                    SortBy               => $Self->{SortBy} || $HeaderColumn,
                    Name                 => $Self->{Name},
                    Title                => $Title,
                },
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemHeaderColumnEmpty',
                Data => {
                    %Param,
                    HeaderNameTranslated => $TranslatedWord || $HeaderColumn,
                    HeaderColumnName     => $HeaderColumn,
                    CSS                  => $CSS,
                    Title                => $Title,
                },
            );
        }
    }

    # show tickets
    my $Count = 0;
    for my $Item ( @{ $Items || [] } ) {
        $Count++;
        #next if $Count < $Self->{StartHit};

        # show ticket
        $LayoutObject->Block(
            Name => 'ContentLargeChecklistItemRow',
            Data => $Item,
        );

        # save column content
        my $DataValue;

        # show all needed columns
        COLUMN:
        for my $Column (@Columns) {

            $LayoutObject->Block(
                Name => 'GeneralOverviewRow',
            );
            $LayoutObject->Block(
                Name => 'ContentLargeChecklistItemTicketColumn',
                Data => {},
            );

            my $BlockType = '';
            my $CSSClass  = '';

            if ( $Column eq 'Status' || $Column eq 'Priority' ) {
                $BlockType = 'Translatable';
                $DataValue = $Item->{$Column};
            }
            elsif ( $Column eq 'DueDate' ) {
                $BlockType = 'Time';
                $DataValue = $Item->{$Column};
            }
            else {
                $DataValue = $Item->{$Column};
            }

            if ( $Column eq 'ChangeAgent' && $Item->{StateChangeBy} ) {
                $Item->{StateChangeAgent} = $UserObject->UserName(
                    UserID => $Item->{StateChangeBy},
                );

                $DataValue = $Item->{StateChangeAgent};
            }

            if ( $Column eq 'TicketTitle' ) {
                $LayoutObject->Block(
                    Name => "ContentLargeTicketTitle",
                    Data => {
                        Title => "$DataValue " || '',
                        WholeTitle => $Item->{$Column},
                        Class      => $CSSClass || '',
                    },
                );

            }
            elsif ( $Column eq 'TicketNumber' ) {
                $LayoutObject->Block(
                    Name => 'ContentLargeChecklistItemTicketNumber',
                    Data => {
                        %{ $Item },
                        Title => $Item->{TicketTitle},
                    },
                );
                next COLUMN;
            }
            else {
                $LayoutObject->Block(
                    Name => "ContentLargeChecklistItemColumn$BlockType",
                    Data => {
                        GenericValue => $DataValue || '',
                        Class        => $CSSClass  || '',
                    },
                );
            }
        }
    }

    # show "none" if no ticket is available
    if ( !$Items || !@{$Items} ) {
        $LayoutObject->Block(
            Name => 'ContentLargeChecklistItemNone',
            Data => {},
        );
    }

    # check for active filters and add a 'remove filters' button to the widget header
    if ( $Self->{GetColumnFilterSelect} && IsHashRefWithData( $Self->{GetColumnFilterSelect} ) ) {
        $LayoutObject->Block(
            Name => 'ContentLargeChecklistItemRemoveFilters',
            Data => {
                Name => $Self->{Name},
            },
        );
    }
    else {
        $LayoutObject->Block(
            Name => 'ContentLargeChecklistItemRemoveFiltersRemove',
            Data => {
                Name => $Self->{Name},
            },
        );
    }

    # show export buttons
    my $ShowExportIcons = $ConfigObject->Get('TicketChecklist::ShowExportIcons') || {};
    if ( $ShowExportIcons->{"Dashboard (MyTodos)"} ) {
        $LayoutObject->Block(
            Name => 'ExportIcons',
            Data => {
            },
        );

        eval {
            require Excel::Writer::XLSX;
            1;
        } and do {
            $LayoutObject->Block(
                Name => 'ExportIconsXLSX',
                Data => {
                },
            );
        };
        
        eval {
            require Data::ICal;
            require Date::ICal;
            1;
        } and do {
            $LayoutObject->Block(
                Name => 'ExportIconsICS',
                Data => {
                },
            );
        };
    }
    # --


    my $Content = $LayoutObject->Output(
        TemplateFile => 'AgentDashboardChecklistItem',
        Data         => {
            %{ $Self->{Config} },
            Name        => $Self->{Name},
            FilterValue => $Self->{Filter},
        },
        KeepScriptTags => $Param{AJAX},
    );

    return $Content;
}

sub _InitialColumnFilter {
    my ( $Self, %Param ) = @_;

    my $LanguageObject  = $Kernel::OM->Get('Kernel::Language');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    my $Label = $Param{Label} || $Param{ColumnName};
    $Label    = $LanguageObject->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => '',
            Value => uc $Label,
        },
    ];

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'Status'
        || $Param{ColumnName} eq 'Priority'
        )
    {
        $TranslationOption = 1;
    }

    my $Class = 'ColumnFilter';
    if ( $Param{Css} ) {
        $Class .= ' ' . $Param{Css};
    }

    # build select HTML
    my $ColumnFilterHTML = $LayoutObject->BuildSelection(
        Name        => 'ColumnFilter' . $Param{ColumnName} . $Self->{Name},
        Data        => $Data,
        Class       => $Class,
        Translation => $TranslationOption,
        SelectedID  => '',
    );
    return $ColumnFilterHTML;
}

=over

=item _ColumnFilterJSON()

    creates a JSON select filter for column header

    my $ColumnFilterJSON = $TicketOverviewSmallObject->_ColumnFilterJSON(
        ColumnName => 'Queue',
        Label      => 'Queue',
        ColumnValues => {
            1 => 'PostMaster',
            2 => 'Junk',
        },
        SelectedValue '1',
    );

=cut

sub _ColumnFilterJSON {
    my ( $Self, %Param ) = @_;

    my $LanguageObject  = $Kernel::OM->Get('Kernel::Language');
    my $LayoutObject    = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    return if !$Param{ColumnName};
    return if !$Self->{ValidFilterableColumns}->{ $Param{ColumnName} };

    my $Label = $Param{Label};
    $Label    = $LanguageObject->Translate($Label);

    # set fixed values
    my $Data = [
        {
            Key   => 'DeleteFilter',
            Value => uc $Label,
        },
        {
            Key      => '-',
            Value    => '-',
            Disabled => 1,
        },
    ];

    if ( $Param{ColumnValues} && ref $Param{ColumnValues} eq 'HASH' ) {

        my %Values = %{ $Param{ColumnValues} };

        # set possible values
        for my $ValueKey ( sort { lc $Values{$a} cmp lc $Values{$b} } keys %Values ) {
            push @{$Data}, {
                Key   => $ValueKey,
                Value => $Values{$ValueKey}
            };
        }
    }

    # define if column filter values should be translatable
    my $TranslationOption = 0;

    if (
        $Param{ColumnName} eq 'Status'
        || $Param{ColumnName} eq 'Priority'
        )
    {
        $TranslationOption = 1;
    }

    # build select HTML
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'ColumnFilter' . $Param{ColumnName} . $Param{DashboardName},
                Data         => $Data,
                Class        => 'ColumnFilter',
                Sort         => 'AlphanumericKey',
                TreeView     => 1,
                SelectedID   => $Param{SelectedValue},
                Translation  => $TranslationOption,
                AutoComplete => 'off',
            },
        ],
    );

    return $JSON;
}

sub _GetStates {
    my ($Self, %Param) = @_;

    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');
    my $StatusObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklistStatus');

    my $OpenStates   = $ConfigObject->Get( 'TicketChecklist::OpenStates' ) || ['open'];
    my %StatusList   = $StatusObject->TicketChecklistStatusList();
    my %ReverseList  = reverse %StatusList;

    my %OpenStateList = map{ $ReverseList{$_} => $_ }@{$OpenStates};

    return %OpenStateList;
}

sub _GetPriorities {
    my ($Self, %Param) = @_;

    my $PriorityObject = $Kernel::OM->Get('Kernel::System::Priority');
    return $PriorityObject->PriorityList();
}

sub _GetUsers {
    my ($Self, %Param) = @_;

    my $ChecklistObject = $Kernel::OM->Get('Kernel::System::PerlServices::TicketChecklist');
    my @Tasks           = $ChecklistObject->TaskSearch(
        UserID       => $Self->{UserID},
        ResolveAgent => 1,
    );

    my %Users = map {
        $_->{StateChangeBy} ?
             ( $_->{StateChangeBy} => $_->{StateChangeAgent} ) :
             ()
    } @Tasks;

    return %Users;
}

1;

=back
