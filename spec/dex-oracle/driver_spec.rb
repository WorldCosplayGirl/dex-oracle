require 'spec_helper'

describe Driver do
    let(:temp_file) { instance_double('Tempfile') }
    let(:class_name) { 'some/Klazz' }
    let(:method_signature) { 'run(III)V' }
    let(:args) { [1, 2, 3] }
    let(:batch_item) {
        {:className=>"some.Klazz", :methodName=>"run", :arguments=>["I:1", "I:2", "I:3"], :id=>"8ea0a5c705617449899c85cec2435356e8be83d6829e12ff109ab0c44c4156c6"}
    }
    let(:driver) {
        allow(temp_file).to receive(:path).and_return('/fake/tmp/file')
        allow(temp_file).to receive(:unlink)
        allow(temp_file).to receive(:close)
        allow(temp_file).to receive(:flush)
        allow(temp_file).to receive(:<<)
        allow(Tempfile).to receive(:new).and_return(temp_file)
        allow(File).to receive(:open).and_yield(temp_file)
        allow(File).to receive(:read)
        allow(JSON).to receive(:parse)
        allow(Driver).to receive(:exec)
        Driver.new(device_id)
    }

    describe '#make_batch_item' do
        let(:device_id) { '' }
        let(:make_batch_item) { driver.make_batch_item(class_name, method_signature, *args) }

        subject { make_batch_item }
        it {
            should eq batch_item
        }
    end

    describe '#run_batch' do
        let(:device_id) { '' }
        let(:batch) { [batch_item] }
        let(:run_batch) { driver.run_batch(batch) }

        subject { run_batch }
        it {
            allow(driver).to receive(:adb)
            expect(temp_file).to receive(:<<).with(batch.to_json).ordered
            #expect(Driver).to receive(:exec).with('adb shell rm /data/local/od-targets.json')
            expect(Driver).to receive(:exec).with("adb push #{temp_file.path} /data/local/od-targets.json")
            expect(Driver).to receive(:exec).with("adb pull /data/local/od-output.json #{temp_file.path}")
            expect(Driver).to receive(:exec).with("adb shell rm /data/local/od-output.json")
            expect(driver).to receive(:adb).with(
                'export CLASSPATH=/data/local/od.zip; app_process /system/bin org.cf.oracle.Driver @/data/local/od-targets.json', false
            )
            subject
        }
    end

    describe '#run_single' do
        context 'with a device id' do
            let(:device_id) { '1234abcd' }

            context 'with integer arguments' do
                subject { driver.run_single(class_name, method_signature, *args) }
                it {
                    allow(driver).to receive(:adb)
                    expect(driver).to receive(:adb).with(
                        "export CLASSPATH=/data/local/od.zip; app_process /system/bin org.cf.oracle.Driver 'some.Klazz' 'run' I:1 I:2 I:3"
                    )
                    subject
                }
            end
        end

        context 'without a device id' do
            let(:device_id) { '' }

            context 'with string argument' do
                let(:class_name) { 'string/Klazz' }
                let(:method_signature) { 'run(Ljava/lang/String;)V' }
                let(:args) { 'hello string' }

                subject { driver.run_single(class_name, method_signature, args) }
                it {
                    allow(driver).to receive(:adb)
                    expect(driver).to receive(:adb).with(
                        "export CLASSPATH=/data/local/od.zip; app_process /system/bin org.cf.oracle.Driver 'string.Klazz' 'run' java.lang.String:[104,101,108,108,111,32,115,116,114,105,110,103]"
                    )
                    subject
                }
            end
        end
    end
end