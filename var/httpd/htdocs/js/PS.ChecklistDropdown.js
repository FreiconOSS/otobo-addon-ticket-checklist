// --
// PS.ChecklistDropdown.js
// --
// Modified by Freicon GmbH & Co. KG, 2026-10-29: item details in the ticket create masks used
// an undefined event, an error message an undefined URL; choosing the customer dropped the
// chosen template and ended in an undefined variable.
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file COPYING for license information (AGPL). If you
// did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
// --

"use strict";

var PS = PS || {};

/**
 * @namespace
 * @exports TargetNS as PS.TicketChecklist
 * @description
 *      This namespace contains the special module functions for the time tracking add on
 */
PS.ChecklistDropdown = (function (TargetNS) {
    TargetNS.Init = function() {
        // subscribe to customer select and update checklist template dropdwon
      
        Core.App.Subscribe( 'Event.Agent.CustomerSearch.GetCustomerInfo.Callback', function(UserCustomerID) {
            // replace text input field with selectbox
            var URL = Core.Config.Get('Baselink');

            var FormData = {
                Action: 'AgentTicketChecklistTemplates',
                Subaction: 'UpdateTemplateList',
                CustomerID: UserCustomerID
            };

            if (!Core.Config.Get('SessionIDCookie')) {
                FormData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
                FormData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
            }

            $.ajax({
                type: 'POST',
                url: URL,
                dataType: 'json',
                data: FormData,
                success: function(Response) {
                    $.each(Response, function (DataKey, DataValue) {
                        var $Element = $('#' + DataKey);

                        if ((!$Element.length || !DataValue) && !$Element.is('textarea')) {
                            return;
                        }

                        // Select elements
                        if ($Element.is('select')) {
                            // keep the template the agent already chose, if the customer may have it
                            var Selected = $Element.val();

                            $Element.empty();

                            $.each(DataValue, function (Index, Value) {
                                var NewOption = new Option(Value[1], Value[0], Value[2], Value[3]);

                                // Check if option must be disabled.
                                if (Value[4]) {
                                    NewOption.disabled = true;
                                }

                                // Overwrite option text, because of wrong html quoting of text content.
                                // (This is needed for IE.)
                                NewOption.innerHTML = Value[1];
                                $Element.append(NewOption);
                            });

                            if (Selected && $Element.find('option[value="' + Selected + '"]').length) {
                                $Element.val(Selected);
                            }

                            // Trigger custom redraw event for InputFields
                            if ($Element.hasClass('Modernize')) {
                                $Element.trigger('redraw.InputField');
                            }

                            return;
                        }

                        // Trigger custom redraw event for InputFields
                        if ($Element.hasClass('Modernize')) {
                            $Element.trigger('redraw.InputField');
                        }
                    });
                },
            });
        });



        // apply ticket checklist
        $('#TicketChecklistID').bind( 'change', function() {
            var URL            = Core.Config.Get('Baselink');
            var TicketFormID   = $('input[name="FormID"]').val();
            var SelectValue    = $(this).val();
            var MultiChecklist = $('#TicketChecklist-MultiChecklist');

            var AddItemsValue = 0;
            if ( MultiChecklist.is(':checked') ) {
                AddItemsValue = 1;
            }

            var FormData = {
                Action: 'AgentTicketChecklistIDSet',
                ChecklistID: SelectValue,
                FormID: TicketFormID,
                AddItemsToChecklist: AddItemsValue
            };
    
            if (!Core.Config.Get('SessionIDCookie')) {
                FormData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
                FormData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
            }
    
            $.ajax({
                url: URL,
                data: FormData,
                dataType: 'json',
                success: function (Response){
                    if ( !Response ) {
                        Core.Exception.Throw('Invalid JSON from ' + URL, 'CommunicationError');
                    }
                    else if ( Response.HasHTML ) {
                        $('#TicketChecklistWidget').remove();
                        $('div[class="SidebarColumn"]').append( Response.HTML );

                        $('#EditChecklistBtn').unbind('click');
                        $('#EditChecklistBtn').bind('click', function (event) {
                            var PopupType = 'TicketAction';
                            Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                            return false;
                        });

                        $('a.ItemInfo').unbind('click');
                        $('a.ItemInfo').bind('click', function (Event) {
                            $('div.ChecklistItemDetails').each( function() { $(this).hide() } );
                    
                            var MouseLeft = parseInt( Event.pageX, 10 ) - 420;
                            var MouseTop  = parseInt( Event.pageY, 10 ) - 150;
                    
                            var ElemID    = $(this).attr('id').replace("Link", "");
                    
                            $('#' + ElemID)
                                .css( 'left',  MouseLeft )
                                .css( 'top',   MouseTop )
                                .show();
                    
                            return false;
                        });

                        $('a.ItemInfoClose').unbind('click');
                        $('a.ItemInfoClose').bind('click', function (Event) {
                            $('div.ChecklistItemDetails').each( function() { $(this).hide() } );
                            return false;
                        });

                        Core.UI.InitWidgetActionToggle();
                    }
                }
           });
        });
    };

    TargetNS.ReloadChecklist = function() {
        var URL          = Core.Config.Get('Baselink');
        var TicketFormID = $('input[name="FormID"]').val();

        var FormData = {
            Action: 'AgentTicketChecklistIDSet',
            Subaction: 'ReloadWidget',
            FormID: TicketFormID
        };

        if (!Core.Config.Get('SessionIDCookie')) {
            FormData[Core.Config.Get('SessionName')] = Core.Config.Get('SessionID');
            FormData[Core.Config.Get('CustomerPanelSessionName')] = Core.Config.Get('SessionID');
        }

        jQuery.ajax({
            url: URL,
            data: FormData,
            dataType: 'json',
            success: function (Response){
                if ( !Response ) {
                    Core.Exception.Throw('Invalid JSON from ' + URL, 'CommunicationError');
                }
                else if ( Response.HasHTML ) {
                    $('#TicketChecklistWidget').remove();
                    $('div[class="SidebarColumn"]').append( Response.HTML );

                    $('#EditChecklistBtn').unbind('click');
                    $('#EditChecklistBtn').bind('click', function (Event) {
                        var PopupType = 'TicketAction';
                        Core.UI.Popup.OpenPopup($(this).attr('href'), PopupType);
                        return false;
                    });

                    $('a.ItemInfo').unbind('click');
                    $('a.ItemInfo').bind('click', function (Event) {
                        $('div.ChecklistItemDetails').each( function() { $(this).hide() } );

                        var MouseLeft = parseInt( Event.pageX, 10 ) - 420;
                        var MouseTop  = parseInt( Event.pageY, 10 ) - 150;

                        var ElemID    = $(this).attr('id').replace("Link", "");

                        $('#' + ElemID)
                            .css( 'left',  MouseLeft )
                            .css( 'top',   MouseTop )
                            .show();

                        return false;
                    });

                    $('a.ItemInfoClose').unbind('click');
                    $('a.ItemInfoClose').bind('click', function (Event) {
                        $('div.ChecklistItemDetails').each( function() { $(this).hide() } );
                        return false;
                    });

                    Core.UI.InitWidgetActionToggle();
                }
            }
        });
    };

    return TargetNS;
}(PS.ChecklistDropdown || {}));
