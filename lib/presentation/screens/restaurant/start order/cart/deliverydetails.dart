import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../constants/restaurant/color.dart';
import '../../../../widget/componets/restaurant/componets/Button.dart';
import '../../../../widget/componets/restaurant/componets/Textform.dart';
import '../../../../widget/componets/restaurant/componets/filterButton.dart';

class DeliveryDetails extends StatefulWidget {
  const DeliveryDetails({super.key});

  @override
  State<DeliveryDetails> createState() => _DeliveryDetailsState();
}
enum PaymentMode {paynow ,paylater }

class _DeliveryDetailsState extends State<DeliveryDetails> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController numberController = TextEditingController();
  final TextEditingController remarkController = TextEditingController();
  final TextEditingController houseController = TextEditingController();
  final TextEditingController stateController = TextEditingController();
  final TextEditingController cityController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController postCodeController = TextEditingController();
  final TextEditingController deliveryController = TextEditingController();

  PaymentMode? _character = PaymentMode.paynow;
  String selectedFilter = "Cash";
  Widget _getBody() {
    switch (selectedFilter) {
      case "Cash":
        return Text('');
      case "Card":
        return  Text('');
      default:
        return Center(
          child: Text('NO DATA AVAILABE'),
        );
    }
  }
  bool ispaynow = false;
  @override
  Widget build(BuildContext context) {
    final heigth = MediaQuery.of(context).size.height * 1;
    final width = MediaQuery.of(context).size.width * 1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title:Text('Due',style: GoogleFonts.poppins(fontWeight: FontWeight.w600,fontSize: 16),),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, ),
          onPressed: () => Navigator.pop(context),
        ),


      ),
      body: SingleChildScrollView(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10,vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer Details ',style: GoogleFonts.poppins(fontWeight: FontWeight.w500),),
              SizedBox(height: 10,),
              CommonTextForm(
                obsecureText: false,
                borderc: 10,
                BorderColor: primarycolor,
                controller: nameController,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Name',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),

              CommonTextForm(
                obsecureText: false,
                controller: emailController,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Email ID (optional)',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),

              CommonTextForm(
                obsecureText: false,
                controller: numberController,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Mobile No',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 25,),

              CommonTextForm(
                obsecureText: false,
                controller: remarkController,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Remarks',
                LabelColor: primarycolor,
              ),
              Divider(),

              Text('Address',style: GoogleFonts.poppins(fontSize: 16,fontWeight: FontWeight.w600),),
              Divider(),
              CommonTextForm(
                obsecureText: false,
                controller: houseController,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'House NO',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),
              CommonTextForm(
                obsecureText: false,
                controller: stateController,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'State',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),
              CommonTextForm(
                obsecureText: false,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'City',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),
              CommonTextForm(
                obsecureText: false,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Area',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),
              CommonTextForm(
                obsecureText: false,
                borderc: 10,
                BorderColor: primarycolor,
                // HintColor: primarycolor,
                // hintText: 'Name',
                labelText: 'Post Code',
                LabelColor: primarycolor,
              ),
              SizedBox(height: 10,),
              Divider(),

              // delivery charge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: width * 0.6,
                    child: CommonTextForm(
                      controller: deliveryController,
                      BorderColor: Colors.grey,
                      obsecureText: false,
                      labelText: 'Delivery Charge',
                      LabelColor: Colors.grey,
                    ),
                  ),

                  CommonButton(
                      bgcolor: Colors.grey.shade300,
                      bordercircular: 5,
                      bordercolor: Colors.grey.shade300,
                      height: heigth * 0.05,
                      width: width *0.3,
                      onTap: (){},
                      child: Text('Apply'))

                ],
              ),

              Divider(),


              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.grey)
                      ),
                      child: ListTile(
                        title: Text('Pay Now',style: GoogleFonts.poppins(fontWeight: FontWeight.w600, ),),
                        leading: Radio<PaymentMode>(
                            value: PaymentMode.paynow,
                            groupValue: _character,
                            activeColor: Colors.black,

                            onChanged:(PaymentMode? value){
                              setState(() {
                                _character = value;
                                // ispaynow = true;
                              });
                            }),
                      ),
                    ),
                  ),
                  SizedBox(width: 5,),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          border: Border.all(width: 1, color: Colors.grey)
                      ),
                      child: ListTile(
                        title: Text('Pay Later'),
                        leading: Radio<PaymentMode>(
                            activeColor: Colors.black,
                            value: PaymentMode.paylater,
                            groupValue: _character,
                            onChanged:(PaymentMode? value){
                              setState(() {
                                _character = value;
                                // ispaynow = false;
                              });
                            }),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                height: 10,
              ),
              _character == PaymentMode.paynow?
              ExpansionTile(
                childrenPadding: EdgeInsets.all(10),
                title:  Text('Payment Type'),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Filterbutton(
                          borderc: 5,
                          title: 'Cash',
                          selectedFilter: selectedFilter,
                          onpressed:() {
                            setState(() {
                              selectedFilter = 'Cash';
                            });
                          }),
                      SizedBox(width: 10,),
                      Filterbutton(
                          borderc: 5,
                          title: 'Card',
                          selectedFilter: selectedFilter,
                          onpressed:() {
                            setState(() {
                              selectedFilter = 'Card';
                            });
                          }),
                    ],)
                ],

              ) :
              SizedBox(),
              SizedBox(
                height: 10,
              ),
              CommonButton(
                  bordercircular: 5,
                  height: heigth * 0.05,
                  onTap: (){},
                  child: Text('Procced',style: GoogleFonts.poppins(fontWeight: FontWeight.w600,color: Colors.white),))


            ],),
        ),
      ),
    );
  }
}
