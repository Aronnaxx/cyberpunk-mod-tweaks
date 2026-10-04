// Local port of "Interactive Edgerunners Mansion" 1.0.1 by DrayStation (Nexus 33561)
// to V's Edgerunners Mansion Reloaded (Nexus 26023). Personal use only - do not upload.
// v1.1: transform fitted on 141 matching meshes (3 cm): rotate -87.2366 deg about Z, shift (-3590.7434, -1290.7410, -78.3474).

module NCAModules

import NightCityAllies.*
import NightCityAllies.Modules.*

public class NCAMansionReloadedModule extends NCAModule {
    public func GetName() -> String {
        return "Edgerunners Mansion Reloaded";
    }

    public func GetAuthor() -> String {
        return "DrayStation (local port to Mansion Reloaded)";
    }

    public func GetPass() -> Int32 {
        return 1;
    }

    public func Load() -> Void {
        // Edgerunners_Mansion_Reloaded
        NCA.R().Location(n"Edgerunners_Mansion_Reloaded");
        NCA.R().AreaTrigger(n"Edgerunners_Mansion_Reloaded", new Vector4(-2451.6686806, 108.6567492, 36.4586444, 1.0000000), 55.0);
		
		// Upper Inside
        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Upper_Railing", new Vector4(-2451.8821672, 112.7251624, 40.6557880, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9478720, 0.3186512))
            .Interaction(n"stand_rail", [n"Slot_1"], new Vector4(-2451.8662710, 112.3958340, 40.6557880, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9478720, 0.3186512));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Upper_Bed", new Vector4(-2445.9748619, 105.9082910, 40.6559253, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.7713872, 0.6363662))
            .Interaction(n"lie_sleep", [n"Slot_1"], new Vector4(-2445.8787026, 104.7415263, 40.6559253, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9924422, 0.1227133));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Upper_Sofa", new Vector4(-2451.8810717, 115.4875830, 40.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.8355001, 0.5494903))
            .Interaction(n"sit_sofa", [n"Slot_1"], new Vector4(-2450.7008568, 116.5558581, 40.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9959352, -0.0900725));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Upper_Shower", new Vector4(-2445.2580494, 116.5213543, 40.6681324, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.0214294, -0.9997704))
            .Interaction(n"stand_shower", [n"Slot_1"], new Vector4(-2445.1449451, 117.7076302, 40.6681324, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.0058976, -0.9999826));


		// Lower Inside
        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Lower_Kitchen", new Vector4(-2465.1711321, 99.9961797, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0096559, -0.9999534))
            .Interaction(n"stand_table", [n"Table_Lean"], new Vector4(-2465.1855805, 100.2955138, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0096559, -0.9999534))
            .Interaction(n"stand_wall", [n"Wall"], new Vector4(-2467.7566817, 103.7160596, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.7199058, -0.6940717));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Lower_Table", new Vector4(-2452.8732698, 112.7926918, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9955475, -0.0942616))
            .Interaction(n"sit_table", [n"Slot_1"], new Vector4(-2452.9311224, 113.9912476, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9955475, -0.0942616));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Lower_Sofa", new Vector4(-2446.8899754, 104.3686062, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.6746705, 0.7381191))
            .Interaction(n"sit_sofa", [n"Slot_1"], new Vector4(-2446.3118832, 104.2161243, 36.6525684, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.6746705, 0.7381191));


		// Balcony
        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Balcony_Railing", new Vector4(-2458.8197496, 95.5171576, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9673488, 0.2534492))
            .Interaction(n"stand_rail", [n"Slot_1"], new Vector4(-2458.8052717, 95.2172138, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9673488, 0.2534492))
            .Interaction(n"stand_rail", [n"Slot_2"], new Vector4(-2447.6362720, 97.1059179, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9997315, 0.0231747));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Balcony_Seats", new Vector4(-2450.0255623, 99.2385656, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9995506, 0.0299796))
            .Interaction(n"sit_sofa", [n"Slot_1"], new Vector4(-2448.1058143, 99.7113099, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9995506, 0.0299796))
            .Interaction(n"sit_sofa", [n"Slot_2"], new Vector4(-2450.0510986, 99.7676128, 36.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9995506, 0.0299796));
			
        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Balcony_H10_View", new Vector4(-2442.6855786, 121.5594414, 36.7525745, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.0078989, 0.9999689))
            .Interaction(n"stand_rail", [n"Slot_1"], new Vector4(-2443.9409583, 121.9369775, 36.6525531, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.0078989, 0.9999689))
            .Interaction(n"stand_wall", [n"Slot_2"], new Vector4(-2451.3288287, 119.2406183, 36.6491047, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0369473, 0.9993173));
			
			
		// Pool	Ara				
        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Outside_Pool", new Vector4(-2449.1597084, 84.9994698, 31.7525745, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.7478694, 0.6638460))
            .Area(n"Pool")
            .Interaction(n"swim", [n"Swim_1"], new Vector4(-2437.2170798, 82.7960799, 30.7940021, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.5424979, 0.8400573))
            .Interaction(n"swim", [n"Swim_2"], new Vector4(-2444.6684601, 83.8815741, 30.7935672, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.7373497, -0.6755113))
            .Interaction(n"swim", [n"Swim_3"], new Vector4(-2441.3400287, 85.6696136, 30.7935672, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9997748, 0.0212240));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Outside_Pool_2", new Vector4(-2449.1597084, 84.9994698, 31.7525745, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.7478694, 0.6638460))
            .Area(n"Pool_2")
            .Slot(n"Sit_1")
            .Interaction(n"sit_chair", [n"Sit_2"], new Vector4(-2449.6071628, 81.2605362, 32.4225650, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0289344, 0.9995813))
            .Interaction(n"sit_chair", [n"Sit_2"], new Vector4(-2455.1797218, 86.3277179, 32.4225650, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.7471956, 0.6646042))
            .Interaction(n"sit_chair", [n"Sit_3"], new Vector4(-2449.9190836, 87.8290639, 32.4345661, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9999778, 0.0066662));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Outside_Bed", new Vector4(-2460.6150024, 89.7459142, 32.6425739, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.9837228, -0.1796932))
            .Interaction(n"lie_couch", [n"Slot_1"], new Vector4(-2460.1968807, 87.7855216, 32.5915714, 1.0000000), new Quaternion(0.0000000, 0.0000000, 0.2815330, 0.9595516))
            .Interaction(n"lie_bench", [n"Slot_1"], new Vector4(-2460.0820416, 87.4597468, 32.6125675, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.9830900, 0.1831230));

        NCA.R().Prop(n"Edgerunners_Mansion_Reloaded", n"Outside_Railing", new Vector4(-2453.2949179, 72.5936578, 32.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0420160, 0.9991170))
            .Interaction(n"stand_wall", [n"Slot_1"], new Vector4(-2453.2804518, 72.2939579, 32.6525074, 1.0000000), new Quaternion(0.0000000, 0.0000000, -0.0420160, 0.9991170));


		// Paths
        NCA.R().Path(n"Edgerunners_Mansion_Reloaded", n"", n"Pool", [
            new Vector4(-2454.6715313, 82.1519285, 32.5345111, 1.0000000),
            new Vector4(-2448.8629965, 83.5769400, 31.7487903, 1.0000000)
        ]);
        NCA.R().Path(n"Edgerunners_Mansion_Reloaded", n"Pool", n"Pool_2", [
            new Vector4(-2449.6273000, 86.5390191, 31.7525745, 1.0000000)
        ]);
        NCA.R().Path(n"Edgerunners_Mansion_Reloaded", n"Pool_2", n"", [
            new Vector4(-2453.5005775, 84.1969673, 31.7525745, 1.0000000),
            new Vector4(-2454.8201070, 83.1082798, 32.5345111, 1.0000000)
        ]);
        NCA.R().Path(n"Edgerunners_Mansion_Reloaded", n"Pool", n"", [
            new Vector4(-2451.7944260, 83.2992994, 31.7525745, 1.0000000),
            new Vector4(-2453.8255528, 81.9615367, 32.5343738, 1.0000000)
        ]);
    }
}
